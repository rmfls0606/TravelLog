//
//  LinkPreviewMemoryCache.swift
//  TravelLog
//
//  Created by 이상민 on 7/5/26.
//

import UIKit

struct CachedLinkPreview {
    let title: String?
    let description: String?
    let image: UIImage?
}

final class LinkPreviewMemoryCache {
    static let shared = LinkPreviewMemoryCache()

    private let countLimit = 50
    private let lock = NSLock()
    private var storage: [String: CachedLinkPreview] = [:]
    private var keys: [String] = []

    private init() { }

    func preview(for url: URL) -> CachedLinkPreview? {
        lock.lock()
        defer { lock.unlock() }

        let key = url.absoluteString
        guard let preview = storage[key] else { return nil }

        moveKeyToRecent(key)
        return preview
    }

    func store(_ preview: CachedLinkPreview, for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        let key = url.absoluteString
        storage[key] = preview
        moveKeyToRecent(key)

        while keys.count > countLimit, let oldest = keys.first {
            removeValue(forKey: oldest)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }

        storage.removeAll()
        keys.removeAll()
    }

    private func moveKeyToRecent(_ key: String) {
        keys.removeAll { $0 == key }
        keys.append(key)
    }

    private func removeValue(forKey key: String) {
        storage.removeValue(forKey: key)
        keys.removeAll { $0 == key }
    }
}
