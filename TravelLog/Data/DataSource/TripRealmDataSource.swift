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

final class TripRealmDataSource{
    private let fileManager = FileManager.default

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

        if let data = try? Data(contentsOf: remoteURL) {
            do {
                try data.write(to: targetURL, options: .atomic)
                return filename
            } catch {
                return nil
            }
        }

        // 오프라인 등으로 직접 다운로드 실패 시 Kingfisher 캐시를 로컬 파일로 승격
        guard let cachedImage = imageFromKingfisherCache(forKey: remoteURLString) else {
            return nil
        }

        let imageData = cachedImage.jpegData(compressionQuality: 0.9) ?? cachedImage.pngData()
        guard let imageData else { return nil }

        do {
            try imageData.write(to: targetURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
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
