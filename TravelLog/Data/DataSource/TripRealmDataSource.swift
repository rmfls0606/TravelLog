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
                    realm.add([departure, destination], update: .modified)
                    
                    let travel = TravelTable(
                        departure: departure,
                        destination: destination,
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
    
    func deleteTrip(trip: TravelTable) -> Completable{
        return Completable.create { completable in
            do{
                let realm = try Realm()
                try realm.write {
                    let journals = realm.objects(JournalTable.self)
                        .filter("tripId == %@", trip.id)
                    
                    for journal in journals{
                        realm.delete(journal)
                    }
                    
                    realm.delete(journals)
                    realm.delete(trip)
                }
                completable(.completed)
            }catch{
                completable(.error(RealmError.deleteFailure))
            }
            
            return Disposables.create()
        }
    }
}
