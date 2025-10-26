//
//  LinkMetadataRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/24/25.
//

import RxSwift
import RealmSwift
import LinkPresentation
import UIKit
internal import Realm

final class LinkMetadataRepositoryImpl: LinkMetadataRepository {
    
    // MARK: - Properties
    private let cache = LinkMetadataCache.shared
    private let realmQueue = DispatchQueue(label: "realm.linkmetadata.queue", qos: .userInitiated)
    
    // 메타데이터 갱신 완료 이벤트 (UI 갱신 트리거)
    static let metadataUpdatedSubject = PublishSubject<ObjectId>()
    
    
    // MARK: - 캐시 조회 (Memory → Realm)
    func fetchCachedMetadata(url: String) -> Single<LinkPreviewEntity?> {
        return Single.create { single in
            let canonical = url.lowercased() as NSString
            
            // NSCache hit
            if let cached = self.cache.object(forKey: canonical) {
                print("[Cache] Memory hit for \(url)")
                single(.success(cached))
                return Disposables.create()
            }
            
            // Realm hit
            self.realmQueue.async {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        if let block = realm.objects(JournalBlockTable.self)
                            .filter("linkURL == %@", url.lowercased())
                            .first {
                            
                            let entity = LinkPreviewEntity(
                                url: block.linkURL ?? url,
                                title: block.linkTitle,
                                description: block.linkDescription,
                                imageFilename: block.linkImagePath
                            )
                            self.cache.setObject(entity, forKey: canonical)
                            
                            DispatchQueue.main.async {
                                print("[Cache] Restored from Realm → Memory (\(url))")
                                single(.success(entity))
                            }
                        } else {
                            DispatchQueue.main.async { single(.success(nil)) }
                        }
                    } catch {
                        DispatchQueue.main.async { single(.failure(error)) }
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    
    // MARK: - 메타데이터 요청 + Realm + Cache 저장
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single.create { single in
            // URL 정규화
            guard let targetURL = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }
            
            let canonical = targetURL.absoluteString.lowercased()
            let provider = LPMetadataProvider()
            
            print("Fetching new metadata for \(canonical)")
            
            // LPMetadataProvider로 메타데이터 요청
            provider.startFetchingMetadata(for: targetURL) { metadata, error in
                guard let metadata = metadata, error == nil else {
                    DispatchQueue.main.async {
                        single(.failure(error ?? NSError(domain: "NoMetadata", code: -2)))
                    }
                    return
                }
                
                let title = metadata.title ?? targetURL.host ?? "링크 미리보기"
                let desc = metadata.value(forKey: "summary") as? String ?? targetURL.absoluteString
                
                func save(filename: String?) {
                    DispatchQueue(label: "realm.linkmetadata.write", qos: .userInitiated).async {
                        autoreleasepool {
                            do {
                                let realm = try Realm()
                                if let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) {
                                    try realm.write {
                                        block.linkURL = canonical
                                        block.linkTitle = title
                                        block.linkDescription = desc
                                        block.linkImagePath = filename
                                        block.metadataUpdatedAt = Date()
                                    }
                                }
                                
                                let entity = LinkPreviewEntity(
                                    url: canonical,
                                    title: title,
                                    description: desc,
                                    imageFilename: filename
                                )
                                
                                // 캐시에 저장
                                self.cache.setObject(entity, forKey: canonical as NSString)
                                
                                // UI 갱신 이벤트 전파
                                DispatchQueue.main.async {
                                    print("Metadata saved & Realm updated for \(canonical)")
                                    single(.success(entity))
                                    LinkMetadataRepositoryImpl.metadataUpdatedSubject.onNext(blockId)
                                }
                            } catch {
                                DispatchQueue.main.async { single(.failure(error)) }
                            }
                        }
                    }
                }
                
                // 이미지 처리
                if let itemProvider = metadata.imageProvider {
                    itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        var filename: String?
                        if let uiImage = image as? UIImage {
                            filename = "\(blockId.stringValue)_preview"
                            Self.saveImageToDocuments(uiImage, filename: filename!)
                        }
                        save(filename: filename)
                    }
                } else {
                    save(filename: nil)
                }
            }
            
            return Disposables.create()
        }
    }
}


// MARK: - FileManager Utilities
extension LinkMetadataRepositoryImpl {
    static func saveImageToDocuments(_ image: UIImage, filename: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = image.jpegData(compressionQuality: 0.7)
        else { return }
        
        let fileURL = dir.appendingPathComponent("\(filename).jpg")
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? data.write(to: fileURL)
        }
    }

    static func loadImageFromDocuments(filename: String?) -> UIImage? {
        guard let filename,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent("\(filename).jpg").path)
    }
}
