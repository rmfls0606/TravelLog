//
//  JournalRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RealmSwift
import RxSwift
internal import Realm

protocol JournalRepositoryType {
    func fetchJournals(for tripId: ObjectId) -> Observable<[JournalTable]>
    func createJournal(for tripId: ObjectId) -> Single<JournalTable>
    func addJournalBlock(journalId: ObjectId, type: JournalBlockType, text: String?) -> Completable
}

final class JournalRepository: JournalRepositoryType {
    private let realm = try! Realm()
    private var notificationTokens: [NotificationToken] = []
    
    // MARK: - Fetch Journals (Realm Notification 기반)
    func fetchJournals(for tripId: ObjectId) -> Observable<[JournalTable]> {
        return Observable.create { [weak self] observer in
            guard let self else { return Disposables.create() }
            
            let results = self.realm.objects(JournalTable.self)
                .filter("tripId == %@", tripId)
                .sorted(byKeyPath: "createdAt", ascending: true)
            
            // ✅ 초기값 즉시 방출
            observer.onNext(Array(results))
            
            // ✅ Realm 변경 감시
            let token = results.observe { changes in
                switch changes {
                case .initial(let collection):
                    observer.onNext(Array(collection))
                case .update(let collection, _, _, _):
                    observer.onNext(Array(collection))
                case .error(let error):
                    observer.onError(error)
                }
            }
            
            // ✅ Token 관리 및 해제
            self.notificationTokens.append(token)
            
            return Disposables.create {
                token.invalidate()
            }
        }
    }
    
    // MARK: - Create Journal
    func createJournal(for tripId: ObjectId) -> Single<JournalTable> {
        return Single.create { [weak self] single in
            guard let self else { return Disposables.create() }
            do {
                let journal = JournalTable(tripId: tripId)
                try self.realm.write { self.realm.add(journal) } // ✅ self.realm 명시
                single(.success(journal))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Add Journal Block
    func addJournalBlock(
        journalId: ObjectId,
        type: JournalBlockType,
        text: String?
    ) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self else { return Disposables.create() }
            do {
                guard let journal = self.realm.object(ofType: JournalTable.self, forPrimaryKey: journalId) else {
                    throw NSError(domain: "JournalNotFound", code: 404)
                }
                let block = JournalBlockTable(
                    journalId: journalId,
                    type: type,
                    order: journal.blocks.count,
                    text: text
                )
                try self.realm.write {
                    self.realm.add(block)         // ✅ 명시적으로 self.realm
                    journal.blocks.append(block)
                }
                completable(.completed)
            } catch {
                completable(.error(error))
            }
            return Disposables.create()
        }
    }
}
