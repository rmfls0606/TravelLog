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
}
