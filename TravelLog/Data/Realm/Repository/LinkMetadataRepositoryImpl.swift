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
    private let provider = LPMetadataProvider()
    private let maxRetryCount = 3
    
    // MARK: - Fetch & Save
    
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single<LinkPreviewEntity>.create { single in
            guard let normalized = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }
            
            self.provider.startFetchingMetadata(for: normalized) { metadata, error in
                if let error = error {
                    self.recordFetchFailure(blockId: blockId, error: error)
                    single(.failure(error))
                    return
                }
                
                guard let metadata = metadata else {
                    let error = NSError(domain: "NoMetadata", code: -2)
                    self.recordFetchFailure(blockId: blockId, error: error)
                    single(.failure(error))
                    return
                }
                
                self.saveMetadata(metadata, blockId: blockId)
                
                let entity = LinkPreviewEntity(
                    url: normalized.absoluteString,
                    title: metadata.title,
                    description: metadata.value(forKey: "summary") as? String,
                    imageFilename: nil
                )
                single(.success(entity))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Realm Write Helpers
    
    private func saveMetadata(_ metadata: LPLinkMetadata, blockId: ObjectId) {
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                do {
                    let realm = try Realm()
                    guard let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) else { return }
                    
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
                } catch {
                    print("Realm saveMetadata error:", error.localizedDescription)
                }
            }
        }
    }
    
    private func recordFetchFailure(blockId: ObjectId, error: Error) {
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                do {
                    let realm = try Realm()
                    guard let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) else { return }
                    try realm.write {
                        block.fetchFailCount += 1
                        if block.fetchFailCount >= self.maxRetryCount {
                            block.metadataUpdatedAt = Date() // 3회 초과 시 쿨다운
                            print("[Cooldown] \(blockId.stringValue): max retries reached")
                        }
                    }
                } catch {
                    print("Realm recordFetchFailure error:", error.localizedDescription)
                }
            }
        }
    }
    
    private func saveImage(provider: NSItemProvider, filename: String) {
        provider.loadObject(ofClass: UIImage.self) { image, _ in
            guard let uiImage = image as? UIImage,
                  let data = uiImage.pngData() else { return }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
            try? data.write(to: url)
        }
    }
    
    static func saveImageToDocuments(_ image: UIImage, filename: String) {
            if let data = image.pngData() {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                    .first!
                    .appendingPathComponent(filename)
                do {
                    try data.write(to: url)
                } catch {
                    print("saveImageToDocuments failed:", error.localizedDescription)
                }
            }
        }
    
    static func loadImageFromDocuments(filename: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(filename)
        return UIImage(contentsOfFile: url.path)
    }
}
