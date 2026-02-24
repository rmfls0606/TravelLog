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
        let country: String
        let imageURL: String?
        let localImageFilename: String?
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
                    return CitySnapshot(
                        id: city.id,
                        cityDocId: city.cityDocId,
                        names: names,
                        country: city.country,
                        imageURL: city.imageURL,
                        localImageFilename: city.localImageFilename
                    )
                }

                for item in snapshots {
                    self.process(snapshot: item, forceRemote: false)
                }
            } catch {
                print("City image backfill failed:", error.localizedDescription)
            }
        }
    }

    func backfillCityImageIfNeeded(cityObjectId: ObjectId, forceRemote: Bool = false) {
        queue.async {
            do {
                let realm = try Realm()
                guard let city = realm.object(ofType: CityTable.self, forPrimaryKey: cityObjectId) else { return }
                if !forceRemote {
                    guard city.imageURL == nil || city.localImageFilename == nil else { return }
                }

                let names = Array(Set([
                    city.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    city.nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
                ].filter { !$0.isEmpty }))

                let snapshot = CitySnapshot(
                    id: city.id,
                    cityDocId: city.cityDocId,
                    names: names,
                    country: city.country,
                    imageURL: city.imageURL,
                    localImageFilename: city.localImageFilename
                )
                self.process(snapshot: snapshot, forceRemote: forceRemote)
            } catch {
                print("City image single backfill failed:", error.localizedDescription)
            }
        }
    }

    private func process(snapshot item: CitySnapshot, forceRemote: Bool) {
        // forceRemote: Firestore 원격 조회 우선 시도 플래그
        // Functions는 실제 온라인일 때만 호출한다.
        let actuallyOnline = SimpleNetworkState.shared.isConnected
        let useRemoteFirestore = forceRemote || actuallyOnline
        print("[CityBackfill] start cityId=\(item.id) names=\(item.names) online=\(actuallyOnline) force=\(forceRemote) imageURL=\(item.imageURL ?? "nil") local=\(item.localImageFilename ?? "nil")")
        var foundDocId: String? = item.cityDocId
        var resolvedImageURL: String? = item.imageURL
        var filename: String?

        // 1) imageURL가 이미 있으면 먼저 로컬 파일 백필 시도 (Kingfisher -> Data)
        if !forceRemote, let existingURL = resolvedImageURL, !existingURL.isEmpty {
            print("[CityBackfill] use existing imageURL first cityId=\(item.id)")
            filename = self.downloadAndStoreImageIfNeeded(
                remoteURLString: existingURL,
                preferredKey: item.names.first ?? "city"
            )
            print("[CityBackfill] existing imageURL local save result cityId=\(item.id) filename=\(filename ?? "nil")")
        }

        // 2) imageURL가 없거나 로컬 저장 실패면 Firestore 조회
        if forceRemote || resolvedImageURL == nil || filename == nil {
            let source: FirestoreSource = useRemoteFirestore ? .default : .cache
            let firestoreResult = self.fetchImageFromFirestore(
                cityDocId: item.cityDocId,
                cityNames: item.names,
                source: source
            )
            if let url = firestoreResult?.imageURL {
                resolvedImageURL = url
                print("[CityBackfill] firestore hit cityId=\(item.id) url=\(url)")
                if let docId = firestoreResult?.cityDocId, !docId.isEmpty {
                    foundDocId = docId
                }
            } else {
                print("[CityBackfill] firestore miss cityId=\(item.id)")
            }
        }

        // 3) Functions fallback
        // forceRemote는 화면 갱신 목적의 적극 경로이므로 네트워크 플래그가 false여도 시도한다.
        let canTryFunctions = forceRemote || actuallyOnline
        if resolvedImageURL == nil && canTryFunctions {
            resolvedImageURL = self.fetchImageURLFromFunction(cityNames: item.names, country: item.country)
            print("[CityBackfill] function result cityId=\(item.id) url=\(resolvedImageURL ?? "nil")")
        }

        guard let finalURL = resolvedImageURL else {
            print("[CityBackfill] stop no imageURL cityId=\(item.id)")
            return
        }

        // 4) 아직 local 파일이 없으면 최종 URL로 다시 시도
        if filename == nil {
            filename = self.downloadAndStoreImageIfNeeded(
                remoteURLString: finalURL,
                preferredKey: item.names.first ?? "city"
            )
            print("[CityBackfill] final local save result cityId=\(item.id) filename=\(filename ?? "nil")")
        }

        do {
            let writeRealm = try Realm()
            guard let target = writeRealm.object(ofType: CityTable.self, forPrimaryKey: item.id) else { return }

            try writeRealm.write {
                if let foundDocId, !foundDocId.isEmpty {
                    target.cityDocId = foundDocId
                }
                target.imageURL = finalURL
                if let filename {
                    target.localImageFilename = filename
                }
                target.lastUpdated = Date()
            }
            print("[CityBackfill] realm write done cityId=\(item.id) imageURL=\(finalURL) local=\(filename ?? target.localImageFilename ?? "nil")")
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

            // 4) legacy prefix on name (nameLower가 없는 문서 fallback)
            let legacyDocs = documents(
                from: db.collection("cities")
                    .order(by: "name")
                    .start(at: [trimmed])
                    .end(at: [trimmed + "\u{f8ff}"])
                    .limit(to: 10),
                source: source
            )

            for doc in legacyDocs {
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
        var err: Error?

        db.collection("cities").document(cityDocId).getDocument(source: source) { snapshot, error in
            defer { semaphore.signal() }
            err = error
            guard let data = snapshot?.data() else { return }
            result = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String)
        }

        let timeout: TimeInterval = (source == .cache) ? 0.6 : 2.0
        _ = semaphore.wait(timeout: .now() + timeout)
        if let err {
            print("[CityBackfill] docId query error source=\(source) id=\(cityDocId) error=\(err.localizedDescription)")
        }
        return result
    }

    private func documents(from query: FirebaseFirestore.Query, source: FirestoreSource) -> [QueryDocumentSnapshot] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [QueryDocumentSnapshot] = []
        var err: Error?

        query.getDocuments(source: source) { snapshot, error in
            defer { semaphore.signal() }
            err = error
            result = snapshot?.documents ?? []
        }

        let timeout: TimeInterval = (source == .cache) ? 0.6 : 2.0
        _ = semaphore.wait(timeout: .now() + timeout)
        if let err {
            print("[CityBackfill] query error source=\(source) error=\(err.localizedDescription)")
        }
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

    private func fetchImageURLFromFunction(cityNames: [String], country: String) -> String? {
        let baseQueries = cityNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var queries = baseQueries
        let countryTrimmed = country.trimmingCharacters(in: .whitespacesAndNewlines)
        if !countryTrimmed.isEmpty {
            queries.append(contentsOf: baseQueries.map { "\($0) \(countryTrimmed)" })
        }
        queries = Array(Set(queries))

        guard !queries.isEmpty else { return nil }

        for cityName in queries {
            let semaphore = DispatchSemaphore(value: 0)
            var result: String?

            functions.httpsCallable("searchCity")
                .call([
                    "query": cityName,
                    "language": "ko",
                    "limit": 10
                ]) { value, error in
                    defer { semaphore.signal() }
                    if let error {
                        print("[CityBackfill] function error query=\(cityName) error=\(error.localizedDescription)")
                    }
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

            _ = semaphore.wait(timeout: .now() + 3.0)
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
        let urlHash = stableHash(remoteURLString)
        let fileExtension = normalizedImageExtension(from: remoteURL)
        let filename = "city_\(sanitized)_\(urlHash).\(fileExtension)"
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

    // Deterministic hash for filename versioning by URL (stable across launches)
    private func stableHash(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return String(hash, radix: 16)
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
