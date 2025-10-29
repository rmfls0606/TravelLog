//
//  URLNormalizer.swift
//  TravelLog
//
//  Created by 이상민 on 10/25/25.
//

import Foundation

struct NormalizedURLResult {
    let url: URL
    let isValidDomain: Bool
}

enum URLNormalizer {
    static func normalized(_ raw: String?) -> NormalizedURLResult? {
        guard var raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        // 1. 공백이 있으면 제거 (혹은 "_"로 대체해도 됨)
        if raw.contains(" ") {
            raw = raw.replacingOccurrences(of: " ", with: "")
        }

        // 2. 문자열 중 URL 패턴 추출
        let pattern = #"https?:\/\/[^\s]+"#
        if let range = raw.range(of: pattern, options: .regularExpression),
           let url = URL(string: String(raw[range])) {
            let valid = hasValidDomain(url)
            return NormalizedURLResult(url: url, isValidDomain: valid)
        }

        // 3. https 자동 붙이기
        let candidate = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
        guard let url = URL(string: candidate) else { return nil }

        let valid = hasValidDomain(url)
        return NormalizedURLResult(url: url, isValidDomain: valid)
    }

    /// 도메인 패턴 유효성 검사
    private static func hasValidDomain(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let domainPattern = #"[a-zA-Z0-9-]+\.[a-zA-Z]{2,}"#
        return host.range(of: domainPattern, options: .regularExpression) != nil
    }
}
