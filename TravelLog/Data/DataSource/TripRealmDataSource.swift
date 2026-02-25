//
//  TripRealmDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import UIKit
import RealmSwift
import RxSwift
import Kingfisher
import FirebaseFirestore
import FirebaseFunctions

final class TripRealmDataSource{
    private let fileManager = FileManager.default
    private lazy var db: Firestore = Firestore.firestore()
    private lazy var functions: Functions = Functions.functions(region: "us-central1")

    func createTrip(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        return Completable.create { completable in
            DispatchQueue.global(qos: .userInitiated).async {
                do{
                    if departure.imageURL == nil || departure.imageURL?.isEmpty == true {
                        departure.imageURL = self.resolveImageURLIfNeeded(for: departure)
                    }
                    if destination.imageURL == nil || destination.imageURL?.isEmpty == true {
                        destination.imageURL = self.resolveImageURLIfNeeded(for: destination)
                    }

                    let departureLocalFilename = self.downloadAndStoreImageIfNeeded(
                        remoteURLString: departure.imageURL,
                        preferredKey: departure.nameEn.isEmpty ? departure.name : departure.nameEn
                    )
                    let destinationLocalFilename = self.downloadAndStoreImageIfNeeded(
                        remoteURLString: destination.imageURL,
                        preferredKey: destination.nameEn.isEmpty ? destination.name : destination.nameEn
                    )

                    let realm = try Realm()
                    try realm.write {
                        func findExistingCity(_ city: CityTable) -> CityTable? {
                            if let docId = city.cityDocId, !docId.isEmpty,
                               let byDocId = realm.objects(CityTable.self)
                                .filter("cityDocId == %@", docId)
                                .first {
                                return byDocId
                            }
                            return realm.objects(CityTable.self)
                                .filter("name == %@", city.name)
                                .first
                        }

                        let departureCity: CityTable
                        if let existingDeparture = findExistingCity(departure) {
                            existingDeparture.nameEn = departure.nameEn
                            existingDeparture.country = departure.country
                            existingDeparture.continent = departure.continent
                            existingDeparture.iataCode = departure.iataCode
                            existingDeparture.latitude = departure.latitude
                            existingDeparture.longitude = departure.longitude
                            existingDeparture.cityDocId = departure.cityDocId ?? existingDeparture.cityDocId
                            existingDeparture.imageURL = departure.imageURL
                            existingDeparture.localImageFilename = departureLocalFilename ?? existingDeparture.localImageFilename
                            existingDeparture.popularityCount = departure.popularityCount
                            existingDeparture.lastUpdated = Date()
                            departureCity = existingDeparture
                        } else {
                            departure.localImageFilename = departureLocalFilename
                            realm.add(departure, update: .modified)
                            departureCity = departure
                        }
                        
                        //도착 도시: 이름 기준으로 중복 체크
                        let destinationCity: CityTable
                        if let existingDestination = findExistingCity(destination) {
                            existingDestination.nameEn = destination.nameEn
                            existingDestination.country = destination.country
                            existingDestination.continent = destination.continent
                            existingDestination.iataCode = destination.iataCode
                            existingDestination.latitude = destination.latitude
                            existingDestination.longitude = destination.longitude
                            existingDestination.cityDocId = destination.cityDocId ?? existingDestination.cityDocId
                            existingDestination.imageURL = destination.imageURL
                            existingDestination.localImageFilename = destinationLocalFilename ?? existingDestination.localImageFilename
                            existingDestination.popularityCount = destination.popularityCount
                            existingDestination.lastUpdated = Date()
                            destinationCity = existingDestination
                        } else {
                            destination.localImageFilename = destinationLocalFilename
                            realm.add(destination, update: .modified)
                            destinationCity = destination
                        }
                        
                        let travel = TravelTable(
                            departure: departureCity,
                            destination: destinationCity,
                            startDate: startDate,
                            endDate: endDate,
                            transport: transport,
                            createdAt: Date(),
                            updateAt: Date()
                        )
                        
                        realm.add(travel)
                    }
                    
                    completable(.completed)
                }catch{
                    completable(.error(RealmError.instanceNotFound))
                }
            }
            
            return Disposables.create()
        }
    }

    private func resolveImageURLIfNeeded(for city: CityTable) -> String? {
        let names = Array(Set([
            city.name.trimmingCharacters(in: .whitespacesAndNewlines),
            city.nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        ].filter { !$0.isEmpty }))
        guard !names.isEmpty else { return nil }

        if let docId = city.cityDocId, !docId.isEmpty,
           let byDocId = fetchImageURLByDocId(docId, timeout: 5.0) {
            return byDocId
        }

        for raw in names {
            let lower = raw.lowercased()
            let end = lower + "\u{f8ff}"

            if let exact = firstImageURL(
                query: db.collection("cities").whereField("name", isEqualTo: raw).limit(to: 1),
                source: .default,
                timeout: 5.0
            ) {
                return exact
            }

            if let exactLower = firstImageURL(
                query: db.collection("cities").whereField("nameLower", isEqualTo: lower).limit(to: 1),
                source: .default,
                timeout: 5.0
            ) {
                return exactLower
            }

            if let prefix = firstImageURL(
                query: db.collection("cities")
                    .order(by: "nameLower")
                    .start(at: [lower])
                    .end(at: [end])
                    .limit(to: 5),
                source: .default,
                timeout: 5.0
            ) {
                return prefix
            }
        }

        return fetchImageURLFromFunction(names: names, country: city.country, timeout: 6.0)
    }

    private func fetchImageURLByDocId(_ docId: String, timeout: TimeInterval) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        db.collection("cities").document(docId).getDocument(source: .default) { snapshot, _ in
            defer { semaphore.signal() }
            guard let data = snapshot?.data() else { return }
            result = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String)
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    private func firstImageURL(
        query: FirebaseFirestore.Query,
        source: FirestoreSource,
        timeout: TimeInterval
    ) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?

        query.getDocuments(source: source) { snapshot, _ in
            defer { semaphore.signal() }
            guard let doc = snapshot?.documents.first else { return }
            let data = doc.data()
            result = (data["imageUrl"] as? String) ?? (data["imageURL"] as? String)
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    private func fetchImageURLFromFunction(names: [String], country: String, timeout: TimeInterval) -> String? {
        var queries = names
        let countryTrimmed = country.trimmingCharacters(in: .whitespacesAndNewlines)
        if !countryTrimmed.isEmpty {
            queries.append(contentsOf: names.map { "\($0) \(countryTrimmed)" })
        }
        queries = Array(Set(queries))

        for query in queries {
            let semaphore = DispatchSemaphore(value: 0)
            var result: String?

            functions.httpsCallable("searchCity")
                .call([
                    "query": query,
                    "language": "ko",
                    "limit": 10
                ]) { value, _ in
                    defer { semaphore.signal() }
                    guard
                        let root = value?.data as? [String: Any],
                        let cities = root["cities"] as? [[String: Any]],
                        !cities.isEmpty
                    else { return }
                    result = cities.first?["imageUrl"] as? String
                }

            _ = semaphore.wait(timeout: .now() + timeout)
            if let result, !result.isEmpty {
                return result
            }
        }
        return nil
    }

    private func downloadAndStoreImageIfNeeded(remoteURLString: String?, preferredKey: String) -> String? {
        guard
            let remoteURLString,
            let remoteURL = normalizedURL(from: remoteURLString),
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

        if let image = retrieveImageViaKingfisher(rawKey: remoteURLString, normalizedURL: remoteURL),
           let imageData = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
            do {
                try imageData.write(to: targetURL, options: .atomic)
                return filename
            } catch {
                return nil
            }
        }
        return nil
    }

    private func normalizedURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed) { return url }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let encoded else { return nil }
        return URL(string: encoded)
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

    private func retrieveImageViaKingfisher(rawKey: String, normalizedURL: URL) -> UIImage? {
        if let cached = imageFromKingfisherCache(rawKey: rawKey, normalizedURL: normalizedURL) {
            return cached
        }

        let semaphore = DispatchSemaphore(value: 0)
        var image: UIImage?
        var failureMessage: String?

        KingfisherManager.shared.retrieveImage(with: normalizedURL) { result in
            defer { semaphore.signal() }
            switch result {
            case .success(let value):
                image = value.image
            case .failure:
                image = nil
                failureMessage = "\(result)"
            }
        }

        _ = semaphore.wait(timeout: .now() + 10.0)
        _ = failureMessage
        return image
    }

    private func imageFromKingfisherCache(rawKey: String, normalizedURL: URL) -> UIImage? {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let keys = Array(Set([rawKey, trimmed, normalizedURL.absoluteString]))
        for key in keys {
            let semaphore = DispatchSemaphore(value: 0)
            var image: UIImage?

            ImageCache.default.retrieveImage(forKey: key) { result in
                defer { semaphore.signal() }
                switch result {
                case .success(let value):
                    image = value.image
                case .failure:
                    break
                }
            }
            _ = semaphore.wait(timeout: .now() + 1.0)
            if let image { return image }
        }
        return nil
    }
    
    func fetchTrips() -> Observable<[TravelTable]> {
        return Observable.create { observer in
            do {
                let realm = try Realm()
                let results = realm.objects(TravelTable.self)
                    .sorted(byKeyPath: "startDate", ascending: true)
                
                observer.onNext(Array(results))
                
                let token: NotificationToken = results.observe { changes in
                    switch changes {
                    case .initial(let collection),
                            .update(let collection, _, _, _):
                        observer.onNext(Array(collection))
                    case .error:
                        observer.onError(RealmError.fetchFailure)
                    }
                }
                
                return Disposables.create {
                    _ = token
                }
                
            } catch {
                observer.onError(RealmError.instanceNotFound)
                return Disposables.create()
            }
        }
    }
    
    func deleteTrip(trip: TravelTable) -> Completable {
        return Completable.create { completable in
            do {
                let realm = try Realm()
                let fileManager = FileManager.default
                let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                
                try realm.write {
                    // trip.id와 연결된 모든 journal 조회
                    let journals = realm.objects(JournalTable.self)
                        .filter("tripId == %@", trip.id)
                    
                    // 각 journal의 blocks까지 같이 삭제
                    for journal in journals {
                        let blocks = realm.objects(JournalBlockTable.self)
                            .filter("journalId == %@", journal.id)
                        
                        //블록 이미지 파일 삭제
                        for block in blocks {
                            
                            //여러 장 사진 삭제
                            for filename in block.imageURLs{
                                let fileURL = docURL.appendingPathComponent("\(filename).jpg")
                                if fileManager.fileExists(atPath: fileURL.path){
                                    try? fileManager.removeItem(at: fileURL)
                                }
                            }
                            
                            if let filename = block.linkImagePath {
                                let fileURL = docURL.appendingPathComponent("\(filename).jpg")
                                if fileManager.fileExists(atPath: fileURL.path) {
                                    try? fileManager.removeItem(at: fileURL)
                                    print("Deleted image:", fileURL.lastPathComponent)
                                }
                            }
                        }
                        
                        //Realm 데이터 삭제
                        realm.delete(blocks)
                        realm.delete(journal)
                    }
                    
                    // trip 삭제
                    realm.delete(trip)
                }
                
                completable(.completed)
            } catch {
                completable(.error(RealmError.deleteFailure))
            }
            return Disposables.create()
        }
    }
}
