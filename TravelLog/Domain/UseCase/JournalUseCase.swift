//
//  JournalUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RealmSwift

protocol JournalUseCaseType {
    func fetchJournals(tripId: ObjectId) -> Observable<[JournalTable]>
    func addJournal(tripId: ObjectId, text: String) -> Completable
}

final class JournalUseCase: JournalUseCaseType {
    private let repository: JournalRepositoryType
    
    init(repository: JournalRepositoryType = JournalRepository()) {
        self.repository = repository
    }
    
    // MARK: - Add Journal
    func addJournal(tripId: ObjectId, text: String) -> Completable {
        repository.createJournal(for: tripId)
            .flatMapCompletable { journal in
                self.repository.addJournalBlock(
                    journalId: journal.id,
                    type: .text,
                    text: text
                )
            }
    }
    
    // MARK: - Fetch Journals
    func fetchJournals(tripId: ObjectId) -> Observable<[JournalTable]> {
        // 그냥 그대로 Observable 체인 반환
        return repository.fetchJournals(for: tripId)
    }
}
