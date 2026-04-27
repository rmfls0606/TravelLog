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
    private static let genericTLDs: Set<String> = [
        "com", "net", "org", "edu", "gov", "mil", "int",
        "biz", "info", "name", "pro", "aero", "asia", "cat", "coop", "jobs", "mobi", "museum", "tel", "travel",
        "app", "dev", "io", "ai", "me", "tv", "gg", "xyz", "site", "online", "store", "shop", "blog", "tech",
        "cloud", "club", "agency", "media", "news", "live", "today", "world", "wiki", "services", "digital",
        "company", "center", "email", "group", "network", "solutions", "systems", "software", "studio", "design"
    ]

    private static let countryCodeTLDs: Set<String> = Set(Locale.isoRegionCodes.map { $0.lowercased() })

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
        guard let host = url.host?.lowercased() else { return false }
        let labels = host.split(separator: ".")

        guard labels.count >= 2 else { return false }
        let domainPattern = #"^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$"#
        guard host.range(of: domainPattern, options: .regularExpression) != nil else {
            return false
        }

        guard let tld = labels.last.map(String.init) else { return false }
        return genericTLDs.contains(tld) || countryCodeTLDs.contains(tld)
    }
}
