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
        linkImage: UIImage?,
        photoDescription: String?,
        photoImages: [UIImage]?,
        voiceFileURL: URL?
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
        linkImage: UIImage?,
        photoDescription: String?,
        photoImages: [UIImage]?,
        voiceFileURL: URL?
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
                // 블록 생성 시각을 실제 저장 시각으로 기록 (00:00 고정 방지)
                let now = Date()
                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: journal.createdAt)
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.second = timeComponents.second
                block.createdAt = calendar.date(from: dateComponents) ?? now
                
                switch type {
                    
                    // 🟦 기존 TEXT 블록 그대로
                case .text:
                    break
                    
                    // 🟪 LINK 블록 기존 코드 그대로
                case .link:
                    let normalizedResult = URLNormalizer.normalized(linkURL)
                    block.linkURL = normalizedResult?.url.absoluteString ?? linkURL
                    block.linkTitle = linkTitle
                    block.linkDescription = linkDescription
                    
                    // 정상 도메인만 네트워크 복구 후 메타데이터 재시도 대상에 포함
                    if let normalized = normalizedResult {
                        if normalized.isValidDomain {
                            block.metadataUpdatedAt = nil
                        } else {
                            block.metadataUpdatedAt = Date()
                        }
                    }
                    
                    // 링크 이미지 저장
                    if let image = linkImage {
                        let filename = "\(block.id.stringValue)_preview"
                        LinkMetadataRepositoryImpl.saveImageToDocuments(image, filename: filename)
                        block.linkImagePath = filename
                    }
                    
                    // 백그라운드 메타데이터
                    if let result = normalizedResult, result.isValidDomain {
                        DispatchQueue.global(qos: .background).async {
                            LinkMetadataRepositoryImpl()
                                .fetchAndSaveMetadata(url: result.url.absoluteString, blockId: block.id)
                                .subscribe()
                                .disposed(by: DisposeBag())
                        }
                    }
                    
                    // PHOTO 블록 추가 로직
                case .photo:
                    // text 필드 → 사진 설명(캡션)으로 사용
                    block.photoDescription = photoDescription
                    
                    // linkImage에 여러 장을 담을 수 없으니,
                    // 사용 측에서 UIImage 1장만 넘기는 케이스를 지원
                    if let images = photoImages, !images.isEmpty {
                        for (index, image) in images.enumerated(){
                            let filename = "\(block.id.stringValue)_photo_\(index)"
                            LinkMetadataRepositoryImpl.saveImageToDocuments(image, filename: filename)
                            block.imageURLs.append(filename)
                        }
                    }
                    
                case .voice:
                    if let sourceURL = voiceFileURL {
                        let fileManager = FileManager.default
                        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                            let filename = "\(block.id.stringValue)_voice.m4a"
                            let destURL = docs.appendingPathComponent(filename)
                            // 중복 시 덮어쓰기
                            if fileManager.fileExists(atPath: destURL.path) {
                                try? fileManager.removeItem(at: destURL)
                            }
                            do {
                                try fileManager.copyItem(at: sourceURL, to: destURL)
                                block.voiceURL = filename
                            } catch {
                                print("Voice copy failed: \(error.localizedDescription)")
                            }
                        }
                    }
                    
                    // 기타 타입 (location, voice 등)
                default:
                    break
                }
                
                // Realm 저장
                try realm.write {
                    journal.blocks.append(block)
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
