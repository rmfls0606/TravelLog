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

                // 새 블록
                let block = JournalBlockTable()
                block.journalId = journalId
                block.type = type
                block.text = text
                block.createdAt = journal.createdAt

                // 정규화 실패해도 원본 저장
                let normalized = URLNormalizer.normalized(linkURL)?.absoluteString ?? linkURL
                block.linkURL = normalized
                block.linkTitle = linkTitle
                block.linkDescription = linkDescription

                if type == .link {
                    if URLNormalizer.normalized(linkURL) == nil {
                        // 유효하지 않은 도메인은 바로 TTL 제외 처리
                        block.metadataUpdatedAt = Date()
                    } else {
                        block.metadataUpdatedAt = nil // 정상 링크 → 추후 갱신 대상
                    }
                }

                if let image = linkImage {
                    let filename = "\(block.id.stringValue)_preview"
                    LinkMetadataRepositoryImpl.saveImageToDocuments(image, filename: filename)
                    block.linkImagePath = filename
                }

                try realm.write {
                    journal.blocks.append(block)
                }

                // Thread-safe: ObjectId만 넘김
                let blockId = block.id

                // 유효한 URL 형식이면 백그라운드 fetch
                if let url = normalized,
                   let u = URL(string: url),
                   u.scheme != nil, u.host != nil {
                    DispatchQueue.global(qos: .background).async {
                        LinkMetadataRepositoryImpl()
                            .fetchAndSaveMetadata(url: url, blockId: blockId)
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
