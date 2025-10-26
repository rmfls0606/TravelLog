//
//  JournalUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RealmSwift
import UIKit

protocol JournalUseCaseType {
    func fetchJournals(tripId: ObjectId) -> Observable<[JournalTable]>
    func addJournal(
        tripId: ObjectId,
        type: JournalBlockType,
        text: String?,
        linkURL: String?,
        linkTitle: String?,
        linkDescription: String?,
        linkImage: UIImage?,
        date: Date
    ) -> Completable
    func deleteJournalBlock(journalId: ObjectId, blockId: ObjectId) -> Completable
}


final class JournalUseCase: JournalUseCaseType {
    private let repository: JournalRepositoryType
    
    init(repository: JournalRepositoryType = JournalRepository()) {
        self.repository = repository
    }
    
    func fetchJournals(tripId: ObjectId) -> Observable<[JournalTable]> {
        repository.fetchJournals(for: tripId)
    }
    
    func addJournal(
        tripId: ObjectId,
        type: JournalBlockType,
        text: String?,
        linkURL: String?,
        linkTitle: String?,
        linkDescription: String?,
        linkImage: UIImage?,
        date: Date
    ) -> Completable {
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
                
                // 기존 Journal 여부
                if let existingJournal = realm.objects(JournalTable.self)
                    .filter("tripId == %@ AND createdAt >= %@ AND createdAt < %@", tripId, startOfDay, endOfDay)
                    .first {
                    self.repository.addJournalBlock(
                        journalId: existingJournal.id,
                        type: type,
                        text: text,
                        linkURL: linkURL,
                        linkTitle: linkTitle,
                        linkDescription: linkDescription,
                        linkImage: linkImage
                    )
                    .subscribe(completable)
                    .disposed(by: DisposeBag())
                    
                } else {
                    self.repository.createJournal(for: tripId, date: startOfDay)
                        .flatMapCompletable { journal in
                            self.repository.addJournalBlock(
                                journalId: journal.id,
                                type: type,
                                text: text,
                                linkURL: linkURL,
                                linkTitle: linkTitle,
                                linkDescription: linkDescription,
                                linkImage: linkImage
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
    
    func deleteJournalBlock(journalId: ObjectId, blockId: ObjectId) -> Completable {
        return Completable.create { completable in
            do {
                let realm = try Realm()
                guard let journal = realm.object(ofType: JournalTable.self, forPrimaryKey: journalId),
                      let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) else {
                    throw NSError(domain: "NotFound", code: 404)
                }
                
                //NSCache 무효화
                if let url = block.linkURL {
                    LinkMetadataCache.shared.removeObject(forKey: url as NSString)
                    print("NSCache removed for:", url)
                }
                
                if let filename = block.linkImagePath {
                    let fileManager = FileManager.default
                    if let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let fileURL = dir.appendingPathComponent("\(filename).jpg")
                        if fileManager.fileExists(atPath: fileURL.path) {
                            try? fileManager.removeItem(at: fileURL)
                        }
                    }
                }
                
                try realm.write {
                    realm.delete(block)
                    if journal.blocks.count == 0 {
                        realm.delete(journal)
                    }
                }
                realm.refresh()
                completable(.completed)
            } catch {
                completable(.error(error))
            }
            return Disposables.create()
        }
    }
}
