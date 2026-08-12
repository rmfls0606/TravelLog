//
//  TicketScanResultMapperTests.swift
//  TravelLogTests
//
//  Created by Claude on 8/9/26.
//

import XCTest
@testable import TravelLog

final class TicketScanResultMapperTests: XCTestCase {

    //MARK: - 서버 응답 전체를 정상적으로 TicketScanResult로 매핑하는지 확인
    func testMapsFullPayload() throws {
        let payload: [String: Any] = [
            "isTicket": true,
            "transport": "airplane",
            "departureCity": "Seoul",
            "departureCountry": "South Korea",
            "destinationCity": "Tokyo",
            "destinationCountry": "Japan",
            "startDate": "2026-09-01",
            "startTime": "14:30",
            "endDate": "2026-09-05",
            "endTime": "09:15",
            "confidence": 0.92,
            "notes": NSNull()
        ]

        let result = try TicketScanResultMapper.map(from: payload)

        XCTAssertTrue(result.isTicket)
        XCTAssertEqual(result.transport, .airplane)
        XCTAssertEqual(result.departureCity, "Seoul")
        XCTAssertEqual(result.destinationCity, "Tokyo")
        XCTAssertEqual(result.confidence, 0.92)
        XCTAssertNotNil(result.startDate)
        XCTAssertNotNil(result.endDate)
    }

    //MARK: - 필수 필드(isTicket, confidence)가 없으면 매핑이 실패하는지 확인
    func testThrowsOnMissingRequiredFields() {
        let payload: [String: Any] = ["transport": "bus"]

        XCTAssertThrowsError(try TicketScanResultMapper.map(from: payload)) { error in
            XCTAssertEqual(error as? TicketScanResultMapper.MappingError, .invalidPayload)
        }
    }

    //MARK: - 티켓으로 인식되지 않은 이미지는 다른 필드가 모두 null이어도 매핑에 성공하는지 확인
    func testMapsNonTicketResultWithoutThrowing() throws {
        let payload: [String: Any] = [
            "isTicket": false,
            "transport": NSNull(),
            "departureCity": NSNull(),
            "departureCountry": NSNull(),
            "destinationCity": NSNull(),
            "destinationCountry": NSNull(),
            "startDate": NSNull(),
            "startTime": NSNull(),
            "endDate": NSNull(),
            "endTime": NSNull(),
            "confidence": 0.0,
            "notes": "This looks like a receipt, not a ticket."
        ]

        let result = try TicketScanResultMapper.map(from: payload)

        XCTAssertFalse(result.isTicket)
        XCTAssertNil(result.transport)
        XCTAssertNil(result.startDate)
        XCTAssertEqual(result.notes, "This looks like a receipt, not a ticket.")
    }

    //MARK: - "airplane"/"bus"/"train" 문자열이 Transport enum으로 정확히 매핑되는지 확인
    func testMapsKnownTransportStrings() {
        XCTAssertEqual(TicketScanResultMapper.mapTransport("airplane"), .airplane)
        XCTAssertEqual(TicketScanResultMapper.mapTransport("bus"), .bus)
        XCTAssertEqual(TicketScanResultMapper.mapTransport("train"), .train)
    }

    //MARK: - 알 수 없거나 없는 transport 문자열은 nil로 매핑되는지 확인
    func testMapsUnknownOrMissingTransportToNil() {
        XCTAssertNil(TicketScanResultMapper.mapTransport("ferry"))
        XCTAssertNil(TicketScanResultMapper.mapTransport(nil))
    }

    //MARK: - 날짜와 시간이 함께 주어지면 두 값을 모두 반영한 Date로 파싱되는지 확인
    func testParsesDateWithTime() throws {
        let date = try XCTUnwrap(TicketScanResultMapper.parseDate(dateString: "2026-09-01", timeString: "14:30"))

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    //MARK: - 시간 없이 날짜만 주어져도 자정 기준 Date로 파싱되는지 확인
    func testParsesDateWithoutTime() throws {
        let date = try XCTUnwrap(TicketScanResultMapper.parseDate(dateString: "2026-09-01", timeString: nil))

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 1)
    }

    //MARK: - 날짜 문자열 자체가 nil이거나 비어 있으면 nil을 반환하는지 확인
    func testParsesNilOrEmptyDateStringToNil() {
        XCTAssertNil(TicketScanResultMapper.parseDate(dateString: nil, timeString: "14:30"))
        XCTAssertNil(TicketScanResultMapper.parseDate(dateString: "", timeString: nil))
    }
}
