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

    // MARK: - 메타데이터 가져오기 및 저장
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single<LinkPreviewEntity>.create { single in
            guard let normalized = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }

            // 매 요청마다 새 provider 생성 (한 번만 fetch 가능)
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

                // Realm에 저장
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
                                    let filename = "\(blockId.stringValue)_preview"
                                    self.saveImage(provider: provider, filename: filename)
                                    block.linkImagePath = filename // 확장자 제외 (삭제 시 일관성 유지)
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
                        block.metadataUpdatedAt = Date()
                        print("[Cooldown] \(blockId.stringValue): max retries reached")
                    }
                }
            } catch {
                print("recordFetchFailure error:", error.localizedDescription)
            }
        }
    }

    // MARK: - 이미지 저장 (JPEG, 1회만)
    private func saveImage(provider: NSItemProvider, filename: String) {
        var hasSaved = false
        provider.loadObject(ofClass: UIImage.self) { image, _ in
            guard !hasSaved, let uiImage = image as? UIImage else { return }
            hasSaved = true
            
            if let data = uiImage.jpegData(compressionQuality: 0.9) {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    .first!.appendingPathComponent("\(filename).jpg")
                do {
                    try data.write(to: url)
                    print("✅ Saved preview:", url.lastPathComponent)
                } catch {
                    print("❌ saveImage error:", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - 정적 이미지 저장/로드 (직접 추가 시)
    static func saveImageToDocuments(_ image: UIImage, filename: String) {
        if let data = image.jpegData(compressionQuality: 0.9) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first!.appendingPathComponent("\(filename).jpg")
            do {
                try data.write(to: url)
                print("✅ Saved manual preview:", url.lastPathComponent)
            } catch {
                print("❌ saveImageToDocuments error:", error.localizedDescription)
            }
        }
    }

    static func loadImageFromDocuments(filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("\(filename).jpg")
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - 이미지 삭제 (파일 이름 일관성 유지)
    static func deleteImageFromDocuments(filename: String) {
        let fileManager = FileManager.default
        guard let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = dir.appendingPathComponent("\(filename).jpg")
        if fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
            print("🗑️ Deleted:", fileURL.lastPathComponent)
        }
    }
}
