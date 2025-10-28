//
//  TripRealmDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import RealmSwift
import RxSwift

final class TripRealmDataSource{
    func createTrip(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        return Completable.create { completable in
            do{
                let realm = try Realm()
                try realm.write {
                    let departureCity: CityTable
                    if let existingDeparture = realm.objects(CityTable.self)
                        .filter("name == %@", departure.name)
                        .first {
                        departureCity = existingDeparture
                    } else {
                        realm.add(departure, update: .modified)
                        departureCity = departure
                    }
                    
                    //도착 도시: 이름 기준으로 중복 체크
                    let destinationCity: CityTable
                    if let existingDestination = realm.objects(CityTable.self)
                        .filter("name == %@", destination.name)
                        .first {
                        destinationCity = existingDestination
                    } else {
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
            
            return Disposables.create()
        }
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
                            if let filename = block.linkImagePath {
                                let fileURL = docURL.appendingPathComponent("\(filename).jpg")
                                if fileManager.fileExists(atPath: fileURL.path) {
                                    try? fileManager.removeItem(at: fileURL)
                                    print("🗑️ Deleted image:", fileURL.lastPathComponent)
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
