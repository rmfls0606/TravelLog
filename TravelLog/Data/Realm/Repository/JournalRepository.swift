//
//  JournalRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RealmSwift
import RxSwift
import UIKit
internal import Realm

protocol JournalRepositoryType {
    func fetchJournals(for tripId: ObjectId) -> Observable<[JournalTable]>
    func createJournal(for tripId: ObjectId, date: Date) -> Single<JournalTable>
    func addJournalBlock(
            journalId: ObjectId,
            type: JournalBlockType,
            text: String?,
            linkURL: String?,
            linkTitle: String?,
            linkDescription: String?,
            linkImage: UIImage?
        ) -> Completable
    func fetchJournalCount(tripId: ObjectId) -> Single<Int>
}
final class JournalRepository: JournalRepositoryType {
    // ⚠️ 전역 Realm 인스턴스 삭제 — 스레드별로 새로 생성
    private var notificationTokens: [NotificationToken] = []
    
    // MARK: - Fetch Journals
    func fetchJournals(for tripId: ObjectId) -> Observable<[JournalTable]> {
        return Observable.create { observer in
            let realm = try! Realm()
            let results = realm.objects(JournalTable.self)
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
            
            return Disposables.create {
                token.invalidate()
            }
        }
    }
    
    // MARK: - Create Journal
    func createJournal(for tripId: ObjectId, date: Date) -> Single<JournalTable> {
        return Single.create { single in
            do {
                let realm = try Realm()
                let journal = JournalTable(tripId: tripId, date: date)
                try realm.write {
                    journal.createdAt = date
                    realm.add(journal)
                }
                single(.success(journal))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Add Journal Block (완벽한 버전)
    func addJournalBlock(
        journalId: ObjectId,
        type: JournalBlockType,
        text: String?,
        linkURL: String?,
        linkTitle: String?,
        linkDescription: String?,
        linkImage: UIImage?
    ) -> Completable {
        return Completable.create { completable in
            do {
                let realm = try Realm()
                guard let journal = realm.object(ofType: JournalTable.self, forPrimaryKey: journalId) else {
                    throw NSError(domain: "JournalNotFound", code: 404)
                }

                // 새 블록 생성
                let block = JournalBlockTable()
                block.type = type
                block.text = text
                
                // URL 정규화
                let normalized = URLNormalizer.normalized(linkURL)?.absoluteString
                block.linkURL = normalized
                block.linkTitle = linkTitle
                block.linkDescription = linkDescription

                // 이미지 저장
                if let image = linkImage {
                    let filename = "\(block.id.stringValue)_preview"
                    LinkMetadataRepositoryImpl.saveImageToDocuments(image, filename: filename)
                    block.linkImagePath = filename
                }

                // Realm에 write
                try realm.write {
                    journal.blocks.append(block)
                }

                // Realm 객체를 빠져나오기 전에 id만 캡처
                let blockId = block.id
                let urlForFetch = normalized

                // ✅ Realm write 블록 종료 후, 백그라운드에서 안전하게 LinkMetadata 호출
                if let url = urlForFetch, !url.isEmpty {
                    DispatchQueue.global(qos: .background).async {
                        LinkMetadataRepositoryImpl()
                            .fetchAndSaveMetadata(url: url, blockId: blockId)
                            .subscribe(
                                onSuccess: { entity in
                                    print("✅ Metadata fetched:", entity.url)
                                },
                                onFailure: { error in
                                    print("⚠️ Metadata fetch failed:", error.localizedDescription)
                                }
                            )
                            .disposed(by: DisposeBag())
                    }
                }

                completable(.completed)
            } catch {
                completable(.error(error))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Fetch Journal Count
    func fetchJournalCount(tripId: ObjectId) -> Single<Int> {
        return Single.create { single in
            do {
                let realm = try Realm()
                let count = realm.objects(JournalTable.self)
                    .filter("tripId == %@", tripId)
                    .count
                single(.success(count))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
}
