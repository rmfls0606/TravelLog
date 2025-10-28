//
//  LinkMetadataRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/24/25.
//

import Foundation
import LinkPresentation
import RealmSwift
import RxSwift
import UIKit
internal import Realm

final class LinkMetadataRepositoryImpl {
    private let maxRetryCount = 3

    // MARK: - Fetch & Save
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single<LinkPreviewEntity>.create { single in
            guard let normalized = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }

            // LPMetadataProvider는 매 요청마다 새로 만들어야 안전
            let provider = LPMetadataProvider()

            provider.startFetchingMetadata(for: normalized) { metadata, error in
                if let error = error {
                    DispatchQueue.global(qos: .background).async {
                        self.recordFetchFailure(blockId: blockId, error: error)
                    }
                    single(.failure(error))
                    return
                }

                guard let metadata = metadata else {
                    let err = NSError(domain: "NoMetadata", code: -2)
                    DispatchQueue.global(qos: .background).async {
                        self.recordFetchFailure(blockId: blockId, error: err)
                    }
                    single(.failure(err))
                    return
                }

                // Realm 저장
                DispatchQueue.global(qos: .background).async {
                    autoreleasepool {
                        do {
                            let realm = try Realm()
                            guard let block = realm.object(ofType: JournalBlockTable.self,
                                                           forPrimaryKey: blockId) else { return }

                            try realm.write {
                                block.linkTitle = metadata.title
                                block.linkDescription = metadata.value(forKey: "summary") as? String
                                if let provider = metadata.imageProvider {
                                    let filename = "\(blockId.stringValue)_preview.png"
                                    self.saveImage(provider: provider, filename: filename)
                                    block.linkImagePath = filename
                                }
                                block.metadataUpdatedAt = Date()
                                block.fetchFailCount = 0
                            }

                            DispatchQueue.main.async {
                                let entity = LinkPreviewEntity(
                                    url: normalized.absoluteString,
                                    title: metadata.title,
                                    description: metadata.value(forKey: "summary") as? String,
                                    imageFilename: nil
                                )
                                single(.success(entity))
                            }
                        } catch {
                            DispatchQueue.main.async { single(.failure(error)) }
                        }
                    }
                }
            }
            return Disposables.create()
        }
    }

    // MARK: - 실패 기록
    private func recordFetchFailure(blockId: ObjectId, error: Error) {
        autoreleasepool {
            do {
                let realm = try Realm()
                guard let block = realm.object(ofType: JournalBlockTable.self,
                                               forPrimaryKey: blockId) else { return }
                try realm.write {
                    block.fetchFailCount += 1
                    if block.fetchFailCount >= maxRetryCount {
                        block.metadataUpdatedAt = Date() // 3회 초과 시 쿨다운
                        print("[Cooldown] \(blockId.stringValue): max retries reached")
                    }
                }
            } catch {
                print("recordFetchFailure error:", error.localizedDescription)
            }
        }
    }

    // MARK: - 이미지 저장/로드
    private func saveImage(provider: NSItemProvider, filename: String) {
        provider.loadObject(ofClass: UIImage.self) { image, _ in
            guard let uiImage = image as? UIImage,
                  let data = uiImage.pngData() else { return }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first!.appendingPathComponent(filename)
            try? data.write(to: url)
        }
    }

    static func saveImageToDocuments(_ image: UIImage, filename: String) {
        if let data = image.pngData() {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first!.appendingPathComponent(filename)
            try? data.write(to: url)
        }
    }

    static func loadImageFromDocuments(filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}
