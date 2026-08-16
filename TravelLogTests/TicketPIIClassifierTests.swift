//
//  TicketPIIClassifierTests.swift
//  TravelLogTests
//
//  Created by Claude on 8/16/26.
//

import XCTest
@testable import TravelLog

final class TicketPIIClassifierTests: XCTestCase {

    //MARK: - 여권번호 형식(영문 1~2자 + 숫자 6~9자리)의 텍스트가 마스킹 대상으로 잡히는지 확인
    func testMasksPassportNumberPattern() {
        let regions = [
            TicketTextRegion(text: "M12345678", boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertEqual(result, [regions[0].boundingBox])
    }

    //MARK: - 영문+숫자가 섞인 6자리 예약번호는 잡고, 흔한 숫자 6자리(가격 등)는 오탐하지 않는지 확인
    func testMasksReservationCodeButNotPlainDigits() {
        let regions = [
            TicketTextRegion(text: "AB12C3", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "123456", boundingBox: CGRect(x: 0, y: 0.2, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertEqual(result, [regions[0].boundingBox])
    }

    //MARK: - 생년월일로 보이는 날짜 형식(YYYY-MM-DD, DD/MM/YYYY)이 마스킹 대상으로 잡히는지 확인
    func testMasksDateOfBirthPatterns() {
        let regions = [
            TicketTextRegion(text: "1990-05-12", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "12/05/1990", boundingBox: CGRect(x: 0, y: 0.2, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertEqual(Set(result.map { $0 }), Set(regions.map { $0.boundingBox }))
    }

    //MARK: - "Passenger"/"성명" 같은 키워드 바로 다음 블록(실제 이름이 적혔을 위치)이 마스킹 대상으로 잡히는지 확인
    func testMasksTextFollowingNameKeyword() {
        let regions = [
            TicketTextRegion(text: "Passenger", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "HONG GILDONG", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.contains(regions[1].boundingBox))
    }

    //MARK: - 도시명, 날짜 형식이 아닌 일반 안내 문구처럼 일정 추출에 필요한 텍스트는 마스킹되지 않는지 확인
    func testDoesNotMaskUnrelatedItineraryText() {
        let regions = [
            TicketTextRegion(text: "Incheon", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "GATE 23", boundingBox: CGRect(x: 0, y: 0.2, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.isEmpty)
    }
}
