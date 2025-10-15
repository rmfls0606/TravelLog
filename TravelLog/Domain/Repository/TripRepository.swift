//
//  TripRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import RxSwift

protocol TripRepository{
    func createTrip(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable
    
    func fetchTrips() -> Observable<[TravelTable]>
    
    func deleteTrip(trip: TravelTable) -> Completable
}
