//
//  CreateTripUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import RxSwift

protocol CreateTripUseCase{
    func execute(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable
}

final class CreateTripUseCaseImpl: CreateTripUseCase{
    
    private let repository: TripRepository
    
    init(repository: TripRepository) {
        self.repository = repository
    }
    
    func execute(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        repository.createTrip(
            departure: departure,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            transport: transport
        )
    }
}
