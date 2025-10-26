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

    // MARK: - 전용 큐 & 캐시
    private let realmQueue = DispatchQueue(label: "realm.linkmetadata.queue", qos: .userInitiated)
    private let cache = LinkMetadataCache.shared

    // MARK: - 캐시 조회 (Memory → Realm → Network)
    func fetchCachedMetadata(url: String) -> Single<LinkPreviewEntity?> {
        return Single.create { single in
            // 메모리 캐시 먼저 확인
            if let cached = self.cache.object(forKey: url.lowercased() as NSString) {
                print("[Cache] Memory hit for \(url)")
                single(.success(cached))
                return Disposables.create()
            }

            // Realm 확인
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
                            // 메모리 캐시에 적재
                            self.cache.setObject(entity, forKey: url.lowercased() as NSString)
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

    // MARK: - 메타데이터 새로 요청 + Realm + Cache 저장
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single.create { single in
            guard let targetURL = URLNormalizer.normalized(url) else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }
            let canonical = targetURL.absoluteString.lowercased()

            // 먼저 NSCache 확인
            if let cached = LinkMetadataCache.shared.object(forKey: canonical as NSString) {
                print("[Cache Hit: NSCache]")
                single(.success(cached))
                return Disposables.create()
            }

            // Realm 캐시 확인
            do {
                let realm = try Realm()
                if let block = realm.objects(JournalBlockTable.self)
                    .filter("linkURL == %@", canonical)
                    .first {

                    print("[Cache Hit: Realm]")
                    let entity = LinkPreviewEntity(
                        url: block.linkURL ?? canonical,
                        title: block.linkTitle,
                        description: block.linkDescription,
                        imageFilename: block.linkImagePath
                    )

                    // NSCache에 등록
                    LinkMetadataCache.shared.setObject(entity, forKey: canonical as NSString)
                    single(.success(entity))
                    return Disposables.create()
                }
            } catch {
                print("Realm cache read failed:", error.localizedDescription)
            }

            // 네트워크 요청 (캐시 미스)
            print("[Cache Miss → Fetch metadata]")
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
                                    }
                                }

                                let entity = LinkPreviewEntity(
                                    url: canonical,
                                    title: title,
                                    description: desc,
                                    imageFilename: filename
                                )

                                //Realm + NSCache 저장 후 콜백
                                LinkMetadataCache.shared.setObject(entity, forKey: canonical as NSString)
                                DispatchQueue.main.async { single(.success(entity)) }

                            } catch {
                                DispatchQueue.main.async { single(.failure(error)) }
                            }
                        }
                    }
                }

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
