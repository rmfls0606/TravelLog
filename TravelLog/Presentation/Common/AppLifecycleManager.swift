//
//  AppLifecycleManager.swift
//  TravelLog
//
//  Created by 이상민 on 10/27/25.
//

import Foundation
import RealmSwift
import RxSwift
internal import Realm

final class AppLifecycleManager {
    static let shared = AppLifecycleManager()
    private init() {}
    
    private var refreshedTodayTripIds = Set<ObjectId>()
    private let disposeBag = DisposeBag()
    
    /// 하루 1회, 해당 trip 내 30일 TTL 만료 및 실패<3회 링크만 갱신
    func refreshExpiredLinkMetadataIfNeeded(for tripId: ObjectId) {
        guard !refreshedTodayTripIds.contains(tripId) else {
            print("Already refreshed TTL for trip today:")
            return
        }
        refreshedTodayTripIds.insert(tripId)
        
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                do {
                    let realm = try Realm()
                    let journalIds = Array(
                        realm.objects(JournalTable.self)
                            .filter("tripId == %@", tripId)
                            .map(\.id)
                    )
                    guard !journalIds.isEmpty else { return }
                    
                    let now = Date()
                    let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
                    
                    let ttlTargets = realm.objects(JournalBlockTable.self)
                        .filter("""
                            type == %@ AND journalId IN %@ AND (
                                metadataUpdatedAt == nil OR
                                metadataUpdatedAt < %@)
                            AND fetchFailCount < %d
                            """,
                            JournalBlockType.link,
                            journalIds,
                            thirtyDaysAgo,
                            3
                        )
                    
                    guard !ttlTargets.isEmpty else {
                        print("No TTL targets for trip:")
                        return
                    }
                    
                    print("TTL targets:", ttlTargets.count, "for trip:")
                    
                    struct Task { let id: ObjectId; let url: String }
                    let tasks = ttlTargets.compactMap { block -> Task? in
                        guard let url = block.linkURL, !url.isEmpty else { return nil }
                        return Task(id: block.id, url: url)
                    }
                    
                    let repo = LinkMetadataRepositoryImpl()
                    for t in tasks {
                        repo.fetchAndSaveMetadata(url: t.url, blockId: t.id)
                            .subscribe(
                                onSuccess: { entity in
                                    print("TTL refreshed:", entity.url)
                                },
                                onFailure: { error in
                                    print("TTL refresh failed:", error.localizedDescription)
                                }
                            )
                            .disposed(by: self.disposeBag)
                    }
                } catch {
                    print("TTL refresh realm error:", error.localizedDescription)
                }
            }
        }
    }
}
