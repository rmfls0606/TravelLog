//
//  NetworkMonitor.swift
//  TravelLog
//
//  Created by 이상민 on 10/27/25.
//

import Foundation
import Network
import RealmSwift
import RxSwift
internal import Realm

final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private var monitor: NWPathMonitor?
    private var isMonitoring = false
    private var currentTripId: ObjectId?
    private let disposeBag = DisposeBag()
    private let queue = DispatchQueue(label: "network.monitor.queue")

    private init() {}

    func startMonitoring(for tripId: ObjectId) {
        if isMonitoring, currentTripId == tripId { return }

        stopMonitoring()
        currentTripId = tripId
        isMonitoring = true

        let m = NWPathMonitor()
        monitor = m

        m.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if path.status == .satisfied, let trip = self.currentTripId {
                print("Connected — refresh pending links for trip:", trip.stringValue)
                self.refreshPendingLinks(for: trip)
            } else {
                print("Initially disconnected — waiting for reconnect…")
            }
        }

        m.start(queue: queue)

        if m.currentPath.status == .satisfied, let trip = currentTripId {
            print("Initially connected — immediate refresh for trip:", trip.stringValue)
            refreshPendingLinks(for: trip)
        }
    }

    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        isMonitoring = false
        currentTripId = nil
    }

    /// 해당 trip 범위에서 metadataUpdatedAt == nil 인 링크만 갱신 시도
    private func refreshPendingLinks(for tripId: ObjectId) {
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                do {
                    let realm = try Realm()

                    // 1) 이 trip의 Journal id
                    let journalIds = Array(
                        realm.objects(JournalTable.self)
                            .filter("tripId == %@", tripId)
                            .map(\.id)
                    )
                    guard !journalIds.isEmpty else {
                        print("No journals for trip:")
                        return
                    }

                    // 2) 아직 한 번도 성공하지 못한 링크
                    let pendingBlocks = realm.objects(JournalBlockTable.self)
                        .filter("type == %@ AND metadataUpdatedAt == nil AND journalId IN %@",
                                JournalBlockType.link, journalIds)

                    guard !pendingBlocks.isEmpty else {
                        print("No pending links to refresh for trip:")
                        return
                    }

                    print("Found \(pendingBlocks.count) pending link(s) for trip")

                    // 값 타입으로만 복사
                    struct Task { let id: ObjectId; let url: String }
                    let tasks: [Task] = pendingBlocks.compactMap { block in
                        guard let url = block.linkURL, !url.isEmpty else { return nil }
                        return Task(id: block.id, url: url)
                    }

                    // Realm 범위를 벗어난 뒤 네트워크 요청
                    let repo = LinkMetadataRepositoryImpl()
                    for t in tasks {
                        repo.fetchAndSaveMetadata(url: t.url, blockId: t.id)
                            .subscribe(
                                onSuccess: { entity in
                                    print("Refreshed after reconnect:")
                                },
                                onFailure: { error in
                                    print("Refresh failed after reconnect:", error.localizedDescription)
                                }
                            )
                            .disposed(by: self.disposeBag)
                    }
                } catch {
                    print("Realm refresh error:", error.localizedDescription)
                }
            }
        }
    }
}
