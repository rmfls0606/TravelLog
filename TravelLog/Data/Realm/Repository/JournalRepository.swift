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

    // MARK: - Add Journal Block
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
                block.journalId = journalId
                block.type = type
                block.text = text
                block.createdAt = journal.createdAt

                // URL 정규화
                let normalizedResult = URLNormalizer.normalized(linkURL)
                block.linkURL = normalizedResult?.url.absoluteString ?? linkURL
                block.linkTitle = linkTitle
                block.linkDescription = linkDescription

                // TTL 관리
                if type == .link {
                    if let normalized = URLNormalizer.normalized(linkURL), normalized.isValidDomain {
                        block.metadataUpdatedAt = nil // 정상 도메인 → 갱신 대상
                    } else {
                        block.metadataUpdatedAt = Date() // 잘못된 도메인 → 즉시 TTL 제외
                    }
                }

                // 이미지 저장
                if let image = linkImage {
                    let filename = "\(block.id.stringValue)_preview"
                    LinkMetadataRepositoryImpl.saveImageToDocuments(image, filename: filename)
                    block.linkImagePath = filename
                }

                try realm.write {
                    journal.blocks.append(block)
                }

                // Thread-safe 전달용 id
                let blockId = block.id

                // 정상 도메인일 때만 백그라운드 fetch
                if let result = normalizedResult,
                   result.isValidDomain {
                    DispatchQueue.global(qos: .background).async {
                        LinkMetadataRepositoryImpl()
                            .fetchAndSaveMetadata(url: result.url.absoluteString, blockId: blockId)
                            .subscribe(
                                onSuccess: { _ in },
                                onFailure: { error in
                                    print("Initial fetch failed:", error.localizedDescription)
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
                case .initial(let col), .update(let col, _, _, _):
                    observer.onNext(Array(col))
                case .error(let error):
                    observer.onError(error)
                }
            }

            return Disposables.create { token.invalidate() }
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

    // MARK: - Fetch Journal Count
    func fetchJournalCount(tripId: ObjectId) -> Single<Int> {
        return Single.create { single in
            do {
                let realm = try Realm()
                let journals = realm.objects(JournalTable.self)
                    .filter("tripId == %@", tripId)
                
                let totalBlocks = journals.reduce(0) { $0 + $1.blocks.count }
                            
                single(.success(totalBlocks))
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
}
