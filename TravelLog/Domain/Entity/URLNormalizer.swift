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
    private static let trackingQueryNames: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "igshid",
        "mc_cid", "mc_eid"
    ]

    private static let genericTLDs: Set<String> = [
        "com", "net", "org", "edu", "gov", "mil", "int",
        "biz", "info", "name", "pro", "aero", "asia", "cat", "coop", "jobs", "mobi", "museum", "tel", "travel",
        "app", "dev", "io", "ai", "me", "tv", "gg", "xyz", "site", "online", "store", "shop", "blog", "tech",
        "cloud", "club", "agency", "media", "news", "live", "today", "world", "wiki", "services", "digital",
        "company", "center", "email", "group", "network", "solutions", "systems", "software", "studio", "design"
    ]

    private static let countryCodeTLDs: Set<String> = Set(
        Locale.Region.isoRegions.map { $0.identifier.lowercased() }
    )

    static func normalized(_ raw: String?) -> NormalizedURLResult? {
        guard var raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if raw.contains(" ") {
            raw = raw.replacingOccurrences(of: " ", with: "")
        }

        let pattern = #"https?:\/\/[^\s]+"#
        if let range = raw.range(of: pattern, options: .regularExpression),
           let url = URL(string: String(raw[range])) {
            let normalizedURL = canonicalURL(from: url)
            let valid = hasValidDomain(normalizedURL)
            return NormalizedURLResult(url: normalizedURL, isValidDomain: valid)
        }

        let candidate = hasScheme(raw) ? raw : "https://\(raw)"
        guard let url = URL(string: candidate) else { return nil }

        let normalizedURL = canonicalURL(from: url)
        let valid = hasValidDomain(normalizedURL)
        return NormalizedURLResult(url: normalizedURL, isValidDomain: valid)
    }

    private static func canonicalURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil

        if components.path == "/" {
            components.path = ""
        } else {
            while components.path.count > 1 && components.path.hasSuffix("/") {
                components.path.removeLast()
            }
        }

        if let queryItems = components.queryItems {
            let filteredItems = queryItems.filter { !isTrackingQuery($0.name) }
            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        }

        return components.url ?? url
    }

    private static func isTrackingQuery(_ name: String) -> Bool {
        let lowercasedName = name.lowercased()
        return lowercasedName.hasPrefix("utm_") || trackingQueryNames.contains(lowercasedName)
    }

    private static func hasScheme(_ raw: String) -> Bool {
        let pattern = #"^[a-zA-Z][a-zA-Z0-9+\-.]*://"#
        return raw.range(of: pattern, options: .regularExpression) != nil
    }

    /// 도메인 패턴 유효성 검사
    private static func hasValidDomain(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }

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
