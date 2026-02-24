//
//  CityImageBackfillService.swift
//  TravelLog
//
//  Created by Codex on 2/24/26.
//

import Foundation
import UIKit
import RealmSwift
import FirebaseFirestore
import FirebaseFunctions
import Kingfisher

final class CityImageBackfillService {
    static let shared = CityImageBackfillService()

    private lazy var db: Firestore = Firestore.firestore()
    private lazy var functions: Functions = Functions.functions(region: "us-central1")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "city.image.backfill.queue", qos: .utility)
    private let runLock = NSLock()
    private var isRunning = false
    private var rerunRequested = false
    
    private struct CitySnapshot {
        let id: ObjectId
        let cityDocId: String?
        let names: [String]
        let imageURL: String?
    }

    private init() {}

    func backfillMissingCityImages() {
        runLock.lock()
        if isRunning {
            rerunRequested = true
            runLock.unlock()
            return
        }
        isRunning = true
        runLock.unlock()

        queue.async {
            defer { self.finishRunAndRetryIfNeeded() }
            do {
                let realm = try Realm()
                let candidates = realm.objects(CityTable.self)
                    .filter("imageURL == nil OR localImageFilename == nil")

                guard !candidates.isEmpty else { return }

                let snapshots: [CitySnapshot] = candidates.map { city in
                    let names = Array(Set([
                        city.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        city.nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
                    ].filter { !$0.isEmpty }))
                    return CitySnapshot(id: city.id, cityDocId: city.cityDocId, names: names, imageURL: city.imageURL)
                }

                for item in snapshots {
                    self.process(snapshot: item)
                }
            } catch {
                print("City image backfill failed:", error.localizedDescription)
            }
        }
    }

    func backfillCityImageIfNeeded(cityObjectId: ObjectId) {
        queue.async {
            do {
                let realm = try Realm()
                guard let city = realm.object(ofType: CityTable.self, forPrimaryKey: cityObjectId) else { return }
                guard city.imageURL == nil || city.localImageFilename == nil else { return }

                let names = Array(Set([
                    city.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    city.nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
                ].filter { !$0.isEmpty }))

                let snapshot = CitySnapshot(
                    id: city.id,
                    cityDocId: city.cityDocId,
                    names: names,
                    imageURL: city.imageURL
                )
                self.process(snapshot: snapshot)
            } catch {
                print("City image single backfill failed:", error.localizedDescription)
            }
        }
    }

    private func process(snapshot item: CitySnapshot) {
        let isOnline = SimpleNetworkState.shared.isConnected
        var foundDocId: String?
        let resolvedImageURL: String?

        if isOnline {
            let firestoreResult = self.fetchImageFromFirestore(
                cityDocId: item.cityDocId,
                cityNames: item.names,
                source: .default
            )
            foundDocId = firestoreResult?.cityDocId

            if let firestoreImageURL = firestoreResult?.imageURL {
                resolvedImageURL = firestoreImageURL
            } else if let existing = item.imageURL, !existing.isEmpty {
                resolvedImageURL = existing
            } else {
                resolvedImageURL = self.fetchImageURLFromFunction(cityNames: item.names)
            }
        } else {
            // 오프라인에서는 빠르게: 기존 URL/문서ID 캐시만 활용 (name prefix 조회 생략)
            if let existing = item.imageURL, !existing.isEmpty {
                resolvedImageURL = existing
            } else if let docId = item.cityDocId, !docId.isEmpty,
                      let cachedURL = imageURLFromDocumentId(docId, source: .cache) {
                foundDocId = docId
                resolvedImageURL = cachedURL
            } else {
                return
            }
        }

        guard let resolvedImageURL else { return }

        let filename = self.downloadAndStoreImageIfNeeded(
            remoteURLString: resolvedImageURL,
            preferredKey: item.names.first ?? "city"
        )

        do {
            let writeRealm = try Realm()
            guard let target = writeRealm.object(ofType: CityTable.self, forPrimaryKey: item.id) else { return }

            try writeRealm.write {
                if let foundDocId, !foundDocId.isEmpty {
                    target.cityDocId = foundDocId
                }
                target.imageURL = resolvedImageURL
                if let filename {
                    target.localImageFilename = filename
                }
                target.lastUpdated = Date()
            }
        } catch {
            print("City image write failed:", error.localizedDescription)
        }
    }

    private func finishRunAndRetryIfNeeded() {
        runLock.lock()
        let shouldRerun = rerunRequested
        rerunRequested = false
        isRunning = false
        runLock.unlock()

        if shouldRerun {
            backfillMissingCityImages()
        }
    }

    private func fetchImageFromFirestore(
        cityDocId: String?,
        cityNames: [String],
        source: FirestoreSource
    ) -> (imageURL: String, cityDocId: String?)? {
        if let cityDocId, !cityDocId.isEmpty,
           let imageURL = imageURLFromDocumentId(cityDocId, source: source) {
            return (imageURL: imageURL, cityDocId: cityDocId)
        }

        let normalizedNames = cityNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !normalizedNames.isEmpty else { return nil }

        for trimmed in normalizedNames {
            let lower = trimmed.lowercased()
            let end = lower + "\u{f8ff}"

            // 1) exact name
            if let value = firstImageURLAndDocId(
                from: db.collection("cities")
                    .whereField("name", isEqualTo: trimmed)
                    .limit(to: 1),
                source: source
            ) {
                return value
            }

            // 2) exact normalized nameLower
            if let value = firstImageURLAndDocId(
                from: db.collection("cities")
                    .whereField("nameLower", isEqualTo: lower)
                    .limit(to: 1),
                source: source
            ) {
                return value
            }

            // 3) prefix on nameLower
            let docs = documents(
                from: db.collection("cities")
                    .order(by: "nameLower")
                    .start(at: [lower])
                    .end(at: [end])
                    .limit(to: 10),
                source: source
            )

            let ranked = docs.sorted { lhs, rhs in
                let l = self.cityRank(data: lhs.data(), queryLower: lower)
                let r = self.cityRank(data: rhs.data(), queryLower: lower)
                if l != r { return l < r }
                let lp = lhs.data()["popularityCount"] as? Int ?? 0
                let rp = rhs.data()["popularityCount"] as? Int ?? 0
                return lp > rp
            }

            for doc in ranked {
                let data = doc.data()
                if let url = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String), !url.isEmpty {
                    return (imageURL: url, cityDocId: doc.documentID)
                }
            }
        }

        return nil
    }

    private func imageURLFromDocumentId(_ cityDocId: String, source: FirestoreSource) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        db.collection("cities").document(cityDocId).getDocument(source: source) { snapshot, _ in
            defer { semaphore.signal() }
            guard let data = snapshot?.data() else { return }
            result = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String)
        }

        let timeout: TimeInterval = (source == .cache) ? 1.2 : 5.0
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    private func documents(from query: FirebaseFirestore.Query, source: FirestoreSource) -> [QueryDocumentSnapshot] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [QueryDocumentSnapshot] = []

        query.getDocuments(source: source) { snapshot, _ in
            defer { semaphore.signal() }
            result = snapshot?.documents ?? []
        }

        let timeout: TimeInterval = (source == .cache) ? 1.2 : 5.0
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    private func firstImageURLAndDocId(
        from query: FirebaseFirestore.Query,
        source: FirestoreSource
    ) -> (imageURL: String, cityDocId: String)? {
        let docs = documents(from: query, source: source)
        for doc in docs {
            let data = doc.data()
            if let url = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String), !url.isEmpty {
                return (imageURL: url, cityDocId: doc.documentID)
            }
        }
        return nil
    }

    private func cityRank(data: [String: Any], queryLower: String) -> Int {
        let name = ((data["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let country = ((data["country"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if name == queryLower { return 0 }
        if name.hasPrefix(queryLower) { return 1 }
        if name.contains(queryLower) { return 2 }
        if country == queryLower { return 3 }
        if country.hasPrefix(queryLower) { return 4 }
        return 5
    }

    private func fetchImageURLFromFunction(cityNames: [String]) -> String? {
        let queries = cityNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !queries.isEmpty else { return nil }

        for cityName in queries {
            let semaphore = DispatchSemaphore(value: 0)
            var result: String?

            functions.httpsCallable("searchCity")
                .call([
                    "query": cityName,
                    "language": "ko",
                    "limit": 10
                ]) { value, _ in
                    defer { semaphore.signal() }
                    guard
                        let root = value?.data as? [String: Any],
                        let cities = root["cities"] as? [[String: Any]],
                        !cities.isEmpty
                    else { return }

                    if let exact = cities.first(where: {
                        (($0["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == cityName
                    }) {
                        result = exact["imageUrl"] as? String
                        return
                    }

                    result = cities.first?["imageUrl"] as? String
                }

            _ = semaphore.wait(timeout: .now() + 8)
            if let result, !result.isEmpty {
                return result
            }
        }

        return nil
    }

    private func downloadAndStoreImageIfNeeded(remoteURLString: String?, preferredKey: String) -> String? {
        guard
            let remoteURLString,
            let remoteURL = URL(string: remoteURLString),
            let cityImageDirectory = cityImageDirectoryURL()
        else { return nil }

        let sanitized = sanitizeFilename(preferredKey)
        let fileExtension = normalizedImageExtension(from: remoteURL)
        let filename = "city_\(sanitized).\(fileExtension)"
        let targetURL = cityImageDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: targetURL.path) {
            return filename
        }

        // 1) Kingfisher 캐시 우선 사용
        if let cachedImage = imageFromKingfisherCache(forKey: remoteURLString),
           let cachedData = cachedImage.jpegData(compressionQuality: 0.9) ?? cachedImage.pngData() {
            do {
                try cachedData.write(to: targetURL, options: .atomic)
                return filename
            } catch {
                return nil
            }
        }

        // 2) 캐시에 없으면 네트워크 다운로드 시도
        if let data = try? Data(contentsOf: remoteURL) {
            do {
                try data.write(to: targetURL, options: .atomic)
                return filename
            } catch {
                return nil
            }
        }

        return nil
    }

    private func cityImageDirectoryURL() -> URL? {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = documents.appendingPathComponent("CityImages", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        return directory
    }

    private func sanitizeFilename(_ value: String) -> String {
        let lower = value.lowercased()
        let sanitized = lower.replacingOccurrences(
            of: "[^a-z0-9가-힣_-]",
            with: "_",
            options: .regularExpression
        )
        return sanitized.isEmpty ? UUID().uuidString : sanitized
    }

    private func normalizedImageExtension(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "webp", "heic", "gif":
            return ext
        default:
            return "jpg"
        }
    }

    private func imageFromKingfisherCache(forKey key: String) -> UIImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var image: UIImage?

        ImageCache.default.retrieveImage(forKey: key) { result in
            defer { semaphore.signal() }
            switch result {
            case .success(let value):
                image = value.image
            case .failure:
                image = nil
            }
        }

        _ = semaphore.wait(timeout: .now() + 1.5)
        return image
    }
}
