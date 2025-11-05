//
//  ThumbnailCacheManager.swift
//  TravelLog
//
//  Created by 이상민 on 11/5/25.
//

import UIKit
import Photos

final class ThumbnailCacheManager{
    static let shared = ThumbnailCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init(){ }
    
    func get(forKey key: String) -> UIImage?{
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String){
        cache.setObject(image, forKey: key as NSString)
    }
}
