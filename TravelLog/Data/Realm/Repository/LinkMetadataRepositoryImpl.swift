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
    
    func fetchCachedMetadata(url: String) -> Single<LinkPreviewEntity?> {
        return Single.create { single in
            do {
                let realm = try Realm()
                if let block = realm.objects(JournalBlockTable.self)
                    .filter("linkURL == %@", url)
                    .first {
                    let entity = LinkPreviewEntity(
                        url: url,
                        title: block.linkTitle,
                        description: block.linkDescription,
                        imageFilename: block.linkImagePath
                    )
                    single(.success(entity))
                } else {
                    single(.success(nil))
                }
            } catch {
                single(.failure(error))
            }
            return Disposables.create()
        }
    }
    
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity> {
        return Single.create { single in
            // URL 정규화
            let normalizedURL: URL? = {
                if url.lowercased().hasPrefix("http") {
                    return URL(string: url)
                } else {
                    return URL(string: "https://" + url)
                }
            }()
            
            guard let targetURL = normalizedURL else {
                single(.failure(NSError(domain: "InvalidURL", code: -1)))
                return Disposables.create()
            }
            
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: targetURL) { metadata, error in
                if let error = error {
                    single(.failure(error))
                    return
                }
                
                guard let metadata = metadata else {
                    single(.failure(NSError(domain: "NoMetadata", code: -2)))
                    return
                }
                
                let title = metadata.title ?? targetURL.host ?? "링크 미리보기"
                let desc = metadata.value(forKey: "summary") as? String ?? targetURL.absoluteString
                var filename: String?
                
                if let itemProvider = metadata.imageProvider {
                    itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        if let uiImage = image as? UIImage {
                            filename = "\(blockId.stringValue)_preview"
                            Self.saveImageToDocuments(uiImage, filename: filename!)
                        }
                        
                        Self.saveToRealm(blockId: blockId,
                                         title: title,
                                         desc: desc,
                                         filename: filename,
                                         single: single,
                                         url: url)
                    }
                } else {
                    Self.saveToRealm(blockId: blockId,
                                     title: title,
                                     desc: desc,
                                     filename: nil,
                                     single: single,
                                     url: url)
                }
            }
            return Disposables.create()
        }
    }
    
    private static func saveToRealm(blockId: ObjectId,
                                    title: String,
                                    desc: String,
                                    filename: String?,
                                    single: @escaping (SingleEvent<LinkPreviewEntity>) -> Void,
                                    url: String) {
        do {
            let realm = try Realm()
            if let block = realm.object(ofType: JournalBlockTable.self, forPrimaryKey: blockId) {
                try realm.write {
                    block.linkTitle = title
                    block.linkDescription = desc
                    block.linkImagePath = filename
                }
            }
            single(.success(LinkPreviewEntity(url: url,
                                              title: title,
                                              description: desc,
                                              imageFilename: filename)))
        } catch {
            single(.failure(error))
        }
    }
}

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
