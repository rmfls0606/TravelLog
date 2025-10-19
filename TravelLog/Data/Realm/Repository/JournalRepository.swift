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
    func createJournal(for tripId: ObjectId, date: Date) -> Single<JournalTable>
    func addJournalBlock(journalId: ObjectId, type: JournalBlockType, text: String?) -> Completable
    func fetchJournalCount(tripId: ObjectId) -> Single<Int>
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
            
            observer.onNext(Array(results))
            
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

            self.notificationTokens.append(token)
            
            return Disposables.create {
                token.invalidate()
            }
        }
    }
    
    // MARK: - Create Journal
    func createJournal(for tripId: ObjectId, date: Date) -> Single<JournalTable> {
        return Single.create { [weak self] single in
            guard let self else { return Disposables.create() }
            do {
                let journal = JournalTable(tripId: tripId, date: date)
                try self.realm.write {
                    journal.createdAt = date
                    self.realm.add(journal)
                }
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
                                text: text,
                                createdAt: journal.createdAt
                            )
                try self.realm.write {
                    self.realm.add(block)
                    journal.blocks.append(block)
                }
                completable(.completed)
            } catch {
                completable(.error(error))
            }
            return Disposables.create()
        }
    }
    
    //MARK: - Fetch Journal Count
    func fetchJournalCount(tripId: ObjectId) -> Single<Int> {
        return Single.create { single in
            do{
                let realm = try Realm()
                let count = realm.objects(JournalTable.self)
                    .filter("tripId == %@", tripId)
                    .count
                single(.success(count))
            }catch{
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
}
