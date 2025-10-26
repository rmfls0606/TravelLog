//
//  LinkMetadataCache.swift
//  TravelLog
//
//  Created by 이상민 on 10/25/25.
//

import Foundation

final class LinkMetadataCache{
    static let shared = NSCache<NSString, LinkPreviewEntity>()
}
