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
    func addJournal(tripId: ObjectId, text: String, date: Date) -> Completable
}

final class JournalUseCase: JournalUseCaseType {
    private let repository: JournalRepositoryType
    
    init(repository: JournalRepositoryType = JournalRepository()) {
        self.repository = repository
    }
    
    func fetchJournals(tripId: ObjectId) -> Observable<[JournalTable]> {
        repository.fetchJournals(for: tripId)
    }
    
    func addJournal(tripId: ObjectId, text: String, date: Date) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self else {
                completable(.error(NSError(domain: "JournalUseCaseNil", code: -1)))
                return Disposables.create()
            }
            
            do {
                let realm = try Realm()
                let startOfDay = Calendar.current.startOfDay(for: date)
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
                
                // Trip 존재 확인
                guard realm.object(ofType: TravelTable.self, forPrimaryKey: tripId) != nil else {
                    throw NSError(domain: "TripNotFound", code: 404)
                }
                
                // 기존 Journal 있는지 확인 (범위 쿼리 사용)
                if let existingJournal = realm.objects(JournalTable.self)
                    .filter("tripId == %@ AND createdAt >= %@ AND createdAt < %@", tripId, startOfDay, endOfDay)
                    .first {
                    self.repository.addJournalBlock(
                        journalId: existingJournal.id,
                        type: .text,
                        text: text
                    )
                    .subscribe(completable)
                    .disposed(by: DisposeBag())
                    
                } else {
                    self.repository.createJournal(for: tripId, date: startOfDay)
                        .flatMapCompletable { journal in
                            self.repository.addJournalBlock(
                                journalId: journal.id,
                                type: .text,
                                text: text
                            )
                        }
                        .subscribe(completable)
                        .disposed(by: DisposeBag())
                }
                
            } catch {
                completable(.error(error))
            }
            
            return Disposables.create()
        }
    }
}
