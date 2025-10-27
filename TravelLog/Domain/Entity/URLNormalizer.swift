//
//  URLNormalizer.swift
//  TravelLog
//
//  Created by 이상민 on 10/25/25.
//

import Foundation

enum URLNormalizer {
    static func normalized(_ raw: String?) -> URL? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        // 도메인 구조 체크: 알파벳+점+최소 2글자 TLD
        let domainPattern = #"^(?:https?:\/\/)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"#
        guard text.range(of: domainPattern, options: .regularExpression) != nil else {
            print("Invalid domain format:", text)
            return nil
        }

        let candidate = text.lowercased()
        if candidate.hasPrefix("http") {
            return URL(string: candidate)
        } else {
            return URL(string: "https://" + candidate)
        }
    }
}
