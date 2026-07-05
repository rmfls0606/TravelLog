//
//  URLNormalizerTests.swift
//  TravelLogTests
//
//  Created by 이상민 on 7/5/26.
//

import XCTest
@testable import TravelLog

final class URLNormalizerTests: XCTestCase {

    //MARK: - 사용자가 scheme 없이 도메인만 입력해도 https URL로 보정되는지 확인
    func testAddsHTTPSWhenSchemeIsMissing() {
        let result = URLNormalizer.normalized("naver.com")

        // 정규화 결과 URL과 유효한 도메인 판정이 기대값과 같은지 검증
        XCTAssertEqual(result?.url.absoluteString, "https://naver.com")
        XCTAssertEqual(result?.isValidDomain, true)
    }

    //MARK: - scheme과 host 대소문자가 달라도 같은 URL로 취급되도록 소문자화되는지 확인
    func testLowercasesSchemeAndHost() {
        let result = URLNormalizer.normalized("HTTPS://Example.COM/path")

        XCTAssertEqual(result?.url.absoluteString, "https://example.com/path")
        XCTAssertEqual(result?.isValidDomain, true)
    }

    //MARK: - 루트 경로와 마지막 슬래시 차이로 같은 주소가 다른 캐시 키가 되지 않도록 정리되는지 확인
    func testRemovesRootAndTrailingSlash() {
        XCTAssertEqual(URLNormalizer.normalized("example.com/")?.url.absoluteString, "https://example.com")
        XCTAssertEqual(URLNormalizer.normalized("example.com/path/")?.url.absoluteString, "https://example.com/path")
    }

    //MARK: - utm_source, fbclid 같은 추적 파라미터는 제거하고 실제 의미 있는 query는 유지하는지 확ㅇ인
    func testRemovesTrackingQueryAndKeepsNormalQuery() {
        let result = URLNormalizer.normalized("https://example.com/path?utm_source=app&name=value&fbclid=123")

        XCTAssertEqual(result?.url.absoluteString, "https://example.com/path?name=value")
    }

    //MARK: - #section 같은 페이지 내부 위치값은 링크 미리보기 캐시 기준에서 제외되는지 확인
    func testRemovesFragment() {
        let result = URLNormalizer.normalized("https://example.com/path#section")

        XCTAssertEqual(result?.url.absoluteString, "https://example.com/path")
    }

    //MARK: - 사용자가 문장 안에 URL을 붙여 넣어도 URL 부분만 추출해 정규화하는지 확인
    func testExtractsURLFromText() {
        let result = URLNormalizer.normalized("방문한 링크: https://Example.com/path/?utm_campaign=test#memo")

        XCTAssertEqual(result?.url.absoluteString, "https://example.com/path")
        XCTAssertEqual(result?.isValidDomain, true)
    }

    //MARK: - 도메인 형식이 아닌 입력은 URL 객체로 만들 수 있어도 유효한 링크로 보지 않는지 확인
    func testRejectsInvalidDomain() {
        let result = URLNormalizer.normalized("not-a-domain")

        XCTAssertEqual(result?.isValidDomain, false)
    }
}
