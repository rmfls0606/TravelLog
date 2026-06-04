//
//  ThumbnailCacheManager.swift
//  TravelLog
//
//  Created by 이상민 on 11/5/25.
//

import UIKit

final class ThumbnailCacheManager{
    static let shared = ThumbnailCacheManager()
    
    private let lock = NSLock()
    private var cache: [String: UIImage] = [:]
    private var costs: [String: Int] = [:]
    private var keys: [String] = []
    private var totalCost = 0
    private let countLimit = 600
    private let totalCostLimit = 80 * 1024 * 1024
    
    private init(){ }
    
    func get(forKey key: String) -> UIImage?{
        lock.lock()
        defer { lock.unlock() }
        
        guard let image = cache[key] else { return nil }
        moveKeyToRecent(key)
        return image
    }
    
    func set(_ image: UIImage, forKey key: String){
        lock.lock()
        defer { lock.unlock() }
        
        if let oldCost = costs[key] {
            totalCost -= oldCost
            keys.removeAll { $0 == key }
        }
        
        let cost = image.memoryCost
        cache[key] = image
        costs[key] = cost
        keys.append(key)
        totalCost += cost
        
        trimIfNeeded()
    }
    
    func removeAll(){
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        costs.removeAll()
        keys.removeAll()
        totalCost = 0
    }
    
    private func moveKeyToRecent(_ key: String) {
        keys.removeAll { $0 == key }
        keys.append(key)
    }
    
    private func trimIfNeeded() {
        while keys.count > countLimit || totalCost > totalCostLimit {
            guard let key = keys.first else { return }
            keys.removeFirst()
            cache.removeValue(forKey: key)
            totalCost -= costs.removeValue(forKey: key) ?? 0
        }
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
