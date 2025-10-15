//
//  FetchTripUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation
import RxSwift

protocol FetchTripUseCase{
    func execute() -> Observable<[TravelTable]>
}


final class FetchTripUseCaseImpl: FetchTripUseCase{
    private let repository: TripRepository
    
    init(repository: TripRepository) {
        self.repository = repository
    }
    
    func execute() -> Observable<[TravelTable]> {
        return repository.fetchTrips()
    }
}
