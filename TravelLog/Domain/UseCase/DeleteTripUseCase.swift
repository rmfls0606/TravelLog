//
//  DeleteTripUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/16/25.
//

import Foundation
import RxSwift

protocol DeleteTripUseCase{
    func execute(trip: TravelTable) -> Completable
}

final class DeleteTripUseCaseImpl: DeleteTripUseCase{
    private let repository: TripRepository
    
    init(repository: TripRepository) {
        self.repository = repository
    }
    
    func execute(trip: TravelTable) -> RxSwift.Completable {
        return repository.deleteTrip(trip: trip)
    }
}
