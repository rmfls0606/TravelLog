//
//  LinkMetadataRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/24/25.
//

import RxSwift
import RealmSwift

protocol LinkMetadataRepository {
    func fetchCachedMetadata(url: String) -> Single<LinkPreviewEntity?>
    func fetchAndSaveMetadata(url: String, blockId: ObjectId) -> Single<LinkPreviewEntity>
}
