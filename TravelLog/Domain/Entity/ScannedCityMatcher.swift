//
//  ScannedCityMatcher.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation

//MARK: - 티켓 스캔으로 얻은 도시 후보 목록에서 국가 힌트를 이용해 가장 알맞은 City를 고르는 순수 로직
enum ScannedCityMatcher {

    // - Parameters:
    //   - candidates: 도시 이름으로 검색해 얻은 후보 목록 (이미 관련도 순으로 정렬되어 있다고 가정)
    //  - countryHint: 티켓에서 함께 추출된 국가 이름 (있다면 동명 도시 중 국가가 일치하는 후보를 우선함)
    static func bestMatch(from candidates: [City], countryHint: String?) -> City? {
        guard !candidates.isEmpty else { return nil }

        guard let countryHint else { return candidates.first }

        let normalizedHint = countryHint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHint.isEmpty else { return candidates.first }

        let countryMatch = candidates.first { candidate in
            candidate.country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedHint
        }

        return countryMatch ?? candidates.first
    }
}
