//
//  TripRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import RxSwift

final class TripRepositoryImpl: TripRepository{
    private let dataSource: TripRealmDataSource
    
    init(dataSource: TripRealmDataSource = TripRealmDataSource()) {
        self.dataSource = dataSource
    }
    
    func createTrip(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        return dataSource.createTrip(
            departure: departure,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            transport: transport)
    }
    
    func fetchTrips() -> Observable<[TravelTable]> {
        return dataSource.fetchTrips()
    }
    
    func deleteTrip(trip: TravelTable) -> Completable {
        dataSource.deleteTrip(trip: trip)
    }
}
