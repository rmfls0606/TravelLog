//
//  TicketScanErrorPresenterTests.swift
//  TravelLogTests
//
//  Created by Claude on 8/10/26.
//

import XCTest
@testable import TravelLog

final class TicketScanErrorPresenterTests: XCTestCase {

    //MARK: - TicketScanError의 모든 케이스가 비어있지 않은 메시지로 변환되는지 확인
    func testAllCasesProduceNonEmptyMessage() {
        let cases: [TicketScanError] = [.offline, .invalidImage, .refused, .serverBusy, .unknown]

        for scanError in cases {
            XCTAssertFalse(TicketScanErrorPresenter.message(for: scanError).isEmpty)
        }
    }

    //MARK: - offline은 네트워크 확인을 안내하는 문구인지 확인
    func testOfflineMessageMentionsConnection() {
        XCTAssertTrue(TicketScanErrorPresenter.message(for: .offline).contains("인터넷"))
    }

    //MARK: - 서로 다른 에러 케이스는 서로 다른 문구를 반환하는지 확인 (사용자가 원인을 구분할 수 있어야 함)
    func testDifferentErrorsProduceDifferentMessages() {
        let messages = Set([
            TicketScanErrorPresenter.message(for: .offline),
            TicketScanErrorPresenter.message(for: .invalidImage),
            TicketScanErrorPresenter.message(for: .refused),
            TicketScanErrorPresenter.message(for: .serverBusy),
            TicketScanErrorPresenter.message(for: .unknown)
        ])

        XCTAssertEqual(messages.count, 5)
    }
}
