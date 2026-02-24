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
    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "city.image.backfill.queue", qos: .utility)

    func backfillMissingCityImages() {
        queue.async {
            do {
                let realm = try Realm()
                let candidates = realm.objects(CityTable.self)
                    .filter("imageURL == nil OR localImageFilename == nil")

                guard !candidates.isEmpty else { return }

                let snapshots: [(id: ObjectId, name: String)] = candidates.map { city in
                    (id: city.id, name: city.name)
                }

                for item in snapshots {
                    let isOnline = SimpleNetworkState.shared.isConnected
                    let firestoreSource: FirestoreSource = isOnline ? .default : .cache
                    let firestoreImageURL = self.fetchImageURLFromFirestore(
                        cityName: item.name,
                        source: firestoreSource
                    )

                    let resolvedImageURL: String?
                    if let firestoreImageURL {
                        resolvedImageURL = firestoreImageURL
                    } else if isOnline {
                        resolvedImageURL = self.fetchImageURLFromFunction(cityName: item.name)
                    } else {
                        resolvedImageURL = nil
                    }
                    guard let resolvedImageURL else { continue }

                    let filename = self.downloadAndStoreImageIfNeeded(
                        remoteURLString: resolvedImageURL,
                        preferredKey: item.name
                    )

                    let writeRealm = try Realm()
                    guard let target = writeRealm.object(ofType: CityTable.self, forPrimaryKey: item.id) else {
                        continue
                    }

                    try writeRealm.write {
                        target.imageURL = resolvedImageURL
                        if let filename {
                            target.localImageFilename = filename
                        }
                        target.lastUpdated = Date()
                    }
                }
            } catch {
                print("City image backfill failed:", error.localizedDescription)
            }
        }
    }

    private func fetchImageURLFromFirestore(cityName: String, source: FirestoreSource) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        db.collection("cities")
            .whereField("name", isEqualTo: cityName)
            .limit(to: 1)
            .getDocuments(source: source) { snapshot, _ in
                defer { semaphore.signal() }
                guard let doc = snapshot?.documents.first else { return }
                result = doc.data()["imageUrl"] as? String
            }

        _ = semaphore.wait(timeout: .now() + 8)
        return result
    }

    private func fetchImageURLFromFunction(cityName: String) -> String? {
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

        _ = semaphore.wait(timeout: .now() + 12)
        return result
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
