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
    
    // Realm 전용 큐(스레드 안전)
    private let realmQueue = DispatchQueue(label: "realm.linkmetadata.queue", qos: .userInitiated)
    
    // MARK: - 캐시 조회
    func fetchCachedMetadata(url: String) -> Single<LinkPreviewEntity?> {
        return Single.create { single in
            self.realmQueue.async {
                autoreleasepool {
                    do {
                        let realm = try Realm()
                        // 저장된 URL은 정규화된 형태일 수 있으니, 원본/정규화 둘 다 확인하고 싶다면 여기서도 정규화해서 비교 가능
                        if let block = realm.objects(JournalBlockTable.self)
                            .filter("linkURL == %@", url)
                            .first {
                            let entity = LinkPreviewEntity(
                                url: block.linkURL ?? url,
                                title: block.linkTitle,
                                description: block.linkDescription,
                                imageFilename: block.linkImagePath
                            )
                            DispatchQueue.main.async { single(.success(entity)) }
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
    
    // MARK: - 메타데이터 새로 요청 + Realm에 저장
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single.create { single in
            guard let targetURL = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }

            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: targetURL) { metadata, error in
                if let error = error {
                    DispatchQueue.main.async { single(.failure(error)) }
                    return
                }
                guard let metadata = metadata else {
                    DispatchQueue.main.async {
                        single(.failure(NSError(domain: "NoMetadata", code: -2)))
                    }
                    return
                }

                let title = metadata.title ?? targetURL.host ?? "링크 미리보기"
                let desc = metadata.value(forKey: "summary") as? String ?? targetURL.absoluteString

                func save(filename: String?) {
                    // Realm은 매번 이 큐 안에서 새로 열기
                    DispatchQueue(label: "realm.linkmetadata.write", qos: .userInitiated).async {
                        autoreleasepool {
                            do {
                                let realm = try Realm()
                                guard let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId)
                                else { throw NSError(domain: "BlockNotFound", code: 404) }

                                try realm.write {
                                    block.linkURL = targetURL.absoluteString
                                    block.linkTitle = title
                                    block.linkDescription = desc
                                    block.linkImagePath = filename
                                }

                                let entity = LinkPreviewEntity(
                                    url: targetURL.absoluteString,
                                    title: title,
                                    description: desc,
                                    imageFilename: filename
                                )
                                DispatchQueue.main.async { single(.success(entity)) }
                            } catch {
                                DispatchQueue.main.async { single(.failure(error)) }
                            }
                        }
                    }
                }

                // 이미지 로드는 별도 비동기
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

// MARK: - Private helpers
private extension LinkMetadataRepositoryImpl {
    
    /// Realm write는 전용 큐에서 수행 후 결과 콜백은 메인으로 전달
    static func saveToRealm(
        blockId: ObjectId,
        canonicalURL: String,
        title: String,
        desc: String,
        filename: String?,
        completeOn single: @escaping (SingleEvent<LinkPreviewEntity>) -> Void
    ) {
        let queue = LinkMetadataRepositoryImpl().realmQueue
        queue.async {
            autoreleasepool {
                do {
                    let realm = try Realm()
                    if let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) {
                        try realm.write {
                            block.linkURL = canonicalURL // 정규화된 URL을 저장
                            block.linkTitle = title
                            block.linkDescription = desc
                            block.linkImagePath = filename
                        }
                    }
                    let entity = LinkPreviewEntity(
                        url: canonicalURL,
                        title: title,
                        description: desc,
                        imageFilename: filename
                    )
                    DispatchQueue.main.async { single(.success(entity)) }
                } catch {
                    DispatchQueue.main.async { single(.failure(error)) }
                }
            }
        }
    }
}

// MARK: - FileManager Utilities
extension LinkMetadataRepositoryImpl {
    static func saveImageToDocuments(_ image: UIImage, filename: String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = image.jpegData(compressionQuality: 0.7)
        else { return }
        try? data.write(to: dir.appendingPathComponent("\(filename).jpg"))
    }
    
    static func loadImageFromDocuments(filename: String?) -> UIImage? {
        guard let filename,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent("\(filename).jpg").path)
    }
}
