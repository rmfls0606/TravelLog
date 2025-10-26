//
//  AppLifecycleManager.swift
//  TravelLog
//
//  Created by 이상민 on 10/27/25.
//

import Foundation
import RxSwift
import RealmSwift
import UIKit

/// 앱 생명주기 단위로 링크 메타데이터 TTL을 관리하는 헬퍼
final class AppLifecycleManager {

    static let shared = AppLifecycleManager()
    private let disposeBag = DisposeBag()

    private init() {}

    // MARK: - 오늘 최초 실행 시 TTL 검사
    func performDailyMetadataCheckIfNeeded() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current

        if let lastCheck = defaults.object(forKey: "lastMetadataCheckDate") as? Date,
           calendar.isDateInToday(lastCheck) {
            print("오늘은 이미 메타데이터 TTL 검사를 수행했습니다.")
            return
        }

        print("오늘 최초 실행 - 링크 메타데이터 TTL 검사 시작")
        refreshExpiredLinkMetadataIfNeeded()
        defaults.set(Date(), forKey: "lastMetadataCheckDate")
    }

    // MARK: - TTL 만료된 링크 전역 검사 (30일 기준)
    private func refreshExpiredLinkMetadataIfNeeded() {
        let ttlDays = 30
        let now = Date()
        let calendar = Calendar.current
        var refreshCount = 0

        do {
            let realm = try Realm()
            let linkBlocks = realm.objects(JournalBlockTable.self)
                .filter("type == %@", JournalBlockType.link.rawValue)

            for block in linkBlocks {
                guard let last = block.metadataUpdatedAt,
                      let url = block.linkURL, !url.isEmpty else { continue }

                if let days = calendar.dateComponents([.day], from: last, to: now).day,
                   days >= ttlDays {
                    refreshCount += 1
                    print("[전역 TTL(30일) 만료] \(url)")

                    LinkMetadataRepositoryImpl()
                        .fetchAndSaveMetadata(url: url, blockId: block.id)
                        .subscribe(
                            onSuccess: { entity in
                                print("[30일 갱신 완료] \(entity.title ?? "-")")
                            },
                            onFailure: { error in
                                print("[갱신 실패] \(error.localizedDescription)")
                            }
                        )
                        .disposed(by: disposeBag)
                }
            }

            if refreshCount > 0 {
                print("오늘 \(refreshCount)개의 링크 메타데이터를 갱신했습니다.")
            } else {
                print("모든 링크의 메타데이터가 30일 이내입니다.")
            }

        } catch {
            print("Realm 접근 실패: \(error.localizedDescription)")
        }
    }
}
