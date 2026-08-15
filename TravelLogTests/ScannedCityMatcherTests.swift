//
//  ScannedCityMatcherTests.swift
//  TravelLogTests
//
//  Created by Claude on 8/10/26.
//

import XCTest
@testable import TravelLog

final class ScannedCityMatcherTests: XCTestCase {

    private func makeCity(name: String, country: String) -> City {
        City(cityId: "\(name)-\(country)", name: name, country: country, lat: 0, lng: 0, imageUrl: nil)
    }

    //MARK: - 후보 목록이 비어 있으면 nil을 반환하는지 확인
    func testReturnsNilForEmptyCandidates() {
        XCTAssertNil(ScannedCityMatcher.bestMatch(from: [], countryHint: "France"))
    }

    //MARK: - countryHint가 없으면 이미 관련도 순으로 정렬된 첫 번째 후보를 그대로 반환하는지 확인
    func testReturnsFirstCandidateWhenNoCountryHint() {
        let candidates = [
            makeCity(name: "Paris", country: "France"),
            makeCity(name: "Paris", country: "United States")
        ]

        let result = ScannedCityMatcher.bestMatch(from: candidates, countryHint: nil)

        XCTAssertEqual(result?.cityId, candidates[0].cityId)
    }

    //MARK: - countryHint와 일치하는 후보가 있으면 순서와 상관없이 그 후보를 우선 선택하는지 확인 (대소문자/공백 무시)
    func testPrefersCandidateMatchingCountryHint() {
        let candidates = [
            makeCity(name: "Paris", country: "United States"),
            makeCity(name: "Paris", country: "France")
        ]

        let result = ScannedCityMatcher.bestMatch(from: candidates, countryHint: "  FRANCE  ")

        XCTAssertEqual(result?.country, "France")
    }

    //MARK: - countryHint와 일치하는 후보가 없으면 첫 번째 후보로 폴백하는지 확인
    func testFallsBackToFirstCandidateWhenCountryHintDoesNotMatch() {
        let candidates = [makeCity(name: "Paris", country: "France")]

        let result = ScannedCityMatcher.bestMatch(from: candidates, countryHint: "Germany")

        XCTAssertEqual(result?.country, "France")
    }

    //MARK: - countryHint가 빈 문자열이면 국가 필터링 없이 첫 번째 후보를 반환하는지 확인
    func testTreatsEmptyCountryHintAsNoHint() {
        let candidates = [
            makeCity(name: "Paris", country: "France"),
            makeCity(name: "Paris", country: "United States")
        ]

        let result = ScannedCityMatcher.bestMatch(from: candidates, countryHint: "   ")

        XCTAssertEqual(result?.cityId, candidates[0].cityId)
    }
}
