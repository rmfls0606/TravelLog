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
    private var cache: [String: CacheNode] = [:]
    private var head: CacheNode?
    private var tail: CacheNode?
    private var totalCost = 0
    private let countLimit = 600
    private let totalCostLimit = 80 * 1024 * 1024
    
    private init(){ }
    
    func get(forKey key: String) -> UIImage?{
        lock.lock()
        defer { lock.unlock() }
        
        guard let node = cache[key] else { return nil }
        moveToHead(node)
        return node.image
    }
    
    func set(_ image: UIImage, forKey key: String){
        lock.lock()
        defer { lock.unlock() }
        
        let cost = image.memoryCost
        
        if let node = cache[key] {
            totalCost -= node.cost
            node.image = image
            node.cost = cost
            totalCost += cost
            moveToHead(node)
            trimIfNeeded()
            return
        }
        
        let node = CacheNode(key: key, image: image, cost: cost)
        cache[key] = node
        insertAtHead(node)
        totalCost += cost
        
        trimIfNeeded()
    }
    
    func removeAll(){
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        head = nil
        tail = nil
        totalCost = 0
    }
    
    private func insertAtHead(_ node: CacheNode) {
        node.previous = nil
        node.next = head
        head?.previous = node
        head = node
        
        if tail == nil {
            tail = node
        }
    }
    
    private func remove(_ node: CacheNode) {
        if node === head {
            head = node.next
        }
        
        if node === tail {
            tail = node.previous
        }
        
        node.previous?.next = node.next
        node.next?.previous = node.previous
        node.previous = nil
        node.next = nil
    }
    
    private func moveToHead(_ node: CacheNode) {
        guard node !== head else { return }
        remove(node)
        insertAtHead(node)
    }
    
    private func trimIfNeeded() {
        while cache.count > countLimit || totalCost > totalCostLimit {
            guard let node = tail else { return }
            remove(node)
            cache.removeValue(forKey: node.key)
            totalCost -= node.cost
        }
    }
}

private final class CacheNode {
    let key: String
    var image: UIImage
    var cost: Int
    var previous: CacheNode?
    var next: CacheNode?
    
    init(key: String, image: UIImage, cost: Int) {
        self.key = key
        self.image = image
        self.cost = cost
    }
}

private extension UIImage {
    var memoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
