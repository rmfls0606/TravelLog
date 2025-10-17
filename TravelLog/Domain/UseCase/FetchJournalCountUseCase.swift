//
//  FetchJournalCountUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/17/25.
//

import Foundation
import RealmSwift
import RxSwift

protocol FetchJournalCountUseCase{
    func execute(tripId: ObjectId) -> Single<Int>
}

final class FetchJournalCountUseCaseImpl: FetchJournalCountUseCase{
    private let repository: JournalRepository
    
    init(repository: JournalRepository) {
        self.repository = repository
    }
    
    func execute(tripId: ObjectId) -> Single<Int> {
        return repository.fetchJournalCount(tripId: tripId)
    }
}
