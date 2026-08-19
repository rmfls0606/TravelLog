//
//  TicketScanErrorMapperTests.swift
//  TravelLogTests
//
//  Created by Claude on 8/10/26.
//

import XCTest
import FirebaseFunctions
@testable import TravelLog

final class TicketScanErrorMapperTests: XCTestCase {

    private func makeFunctionsError(_ code: FunctionsErrorCode) -> NSError {
        NSError(domain: FunctionsErrorDomain, code: code.rawValue)
    }

    //MARK: - invalidArgument(잘못된 이미지)는 invalidImage로 매핑되는지 확인
    func testMapsInvalidArgumentToInvalidImage() {
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.invalidArgument)), .invalidImage)
    }

    //MARK: - failedPrecondition(모델의 거부 응답)은 refused로 매핑되는지 확인
    func testMapsFailedPreconditionToRefused() {
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.failedPrecondition)), .refused)
    }

    //MARK: - 서버 과부하/지연성 코드들은 serverBusy로 매핑되는지 확인
    func testMapsOverloadedCodesToServerBusy() {
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.resourceExhausted)), .serverBusy)
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.unavailable)), .serverBusy)
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.deadlineExceeded)), .serverBusy)
    }

    //MARK: - 그 외 Functions 에러 코드는 unknown으로 매핑되는지 확인
    func testMapsOtherFunctionsErrorCodesToUnknown() {
        XCTAssertEqual(TicketScanErrorMapper.map(makeFunctionsError(.internal)), .unknown)
    }

    //MARK: - 인터넷 연결 관련 NSURLErrorDomain 코드는 offline으로 매핑되는지 확인
    func testMapsConnectivityErrorsToOffline() {
        let notConnected = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let timedOut = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        XCTAssertEqual(TicketScanErrorMapper.map(notConnected), .offline)
        XCTAssertEqual(TicketScanErrorMapper.map(timedOut), .offline)
    }

    //MARK: - Functions/네트워크 도메인이 아닌 에러는 unknown으로 매핑되는지 확인
    func testMapsUnrelatedErrorsToUnknown() {
        let other = NSError(domain: "com.example.other", code: 1)
        XCTAssertEqual(TicketScanErrorMapper.map(other), .unknown)
    }
}
