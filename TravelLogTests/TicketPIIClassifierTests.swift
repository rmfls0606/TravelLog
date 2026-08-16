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

    //MARK: - 국내/국제 전화번호 형식(하이픈·공백·괄호·선행 +)이 마스킹 대상으로 잡히는지 확인
    func testMasksPhoneNumberPatterns() {
        let regions = [
            TicketTextRegion(text: "010-1234-5678", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "+33 1 23 45 67 89", boundingBox: CGRect(x: 0, y: 0.2, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertEqual(Set(result), Set(regions.map { $0.boundingBox }))
    }

    //MARK: - 게이트 번호 같은 짧은 숫자, 가격 같은 6자리 이하 순수 숫자는 전화번호로 오탐하지 않는지 확인
    func testDoesNotMaskShortOrPlainDigitSequencesAsPhoneNumber() {
        let regions = [
            TicketTextRegion(text: "23", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "150000", boundingBox: CGRect(x: 0, y: 0.2, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.isEmpty)
    }

    //MARK: - "Nom"(프랑스어)처럼 영어/한중일 외 언어의 이름 키워드 다음 블록도 마스킹 대상으로 잡히는지 확인
    func testMasksTextFollowingNonEnglishNameKeyword() {
        let regions = [
            TicketTextRegion(text: "Nom", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "MARTIN DUPONT", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.contains(regions[1].boundingBox))
    }

    //MARK: - "Tel"/"연락처" 키워드 다음 블록(전화번호가 적혔을 위치)이 마스킹 대상으로 잡히는지 확인
    func testMasksTextFollowingPhoneKeyword() {
        let regions = [
            TicketTextRegion(text: "연락처", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "01012345678", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.contains(regions[1].boundingBox))
    }

    //MARK: - "Contact" 키워드 다음 블록(e-ticket 예약 확인서에 흔한 표기)도 마스킹 대상으로 잡히는지 확인
    func testMasksTextFollowingContactKeyword() {
        let regions = [
            TicketTextRegion(text: "Contact No.", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "+82 10 1234 5678", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.contains(regions[1].boundingBox))
    }

    //MARK: - "SEAT"/"좌석" 키워드 다음 블록(좌석번호가 적혔을 위치)이 마스킹 대상으로 잡히는지 확인
    func testMasksTextFollowingSeatKeyword() {
        let regions = [
            TicketTextRegion(text: "SEAT", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "34A", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.contains(regions[1].boundingBox))
    }

    //MARK: - "TEL"이 "HOTEL"처럼 다른 단어의 일부로 포함된 경우까지 키워드로 오인하지 않는지 확인
    func testDoesNotMatchKeywordAsSubstringOfAnotherWord() {
        let regions = [
            TicketTextRegion(text: "HOTEL RESERVATION", boundingBox: CGRect(x: 0, y: 0.3, width: 0.1, height: 0.05)),
            TicketTextRegion(text: "Grand Hotel Seoul", boundingBox: CGRect(x: 0, y: 0.2, width: 0.2, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.isEmpty)
    }

    //MARK: - 좌석 키워드 없이 단독으로 나오는 "34A" 같은 짧은 영숫자는 게이트/편명과 구분이 안 돼 마스킹하지 않는지 확인
    func testDoesNotMaskSeatLikeTextWithoutSeatKeyword() {
        let regions = [
            TicketTextRegion(text: "34A", boundingBox: CGRect(x: 0, y: 0, width: 0.1, height: 0.05)),
        ]

        let result = TicketPIIClassifier.regionsToMask(in: regions)

        XCTAssertTrue(result.isEmpty)
    }
}
