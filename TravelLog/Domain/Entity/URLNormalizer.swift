//
//  URLNormalizer.swift
//  TravelLog
//
//  Created by 이상민 on 10/25/25.
//

import Foundation

enum URLNormalizer {
    static func normalized(_ raw: String?) -> URL? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }

        // 중간 공백 제거 (연속 스페이스 포함)
        text = text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        // http/https가 없으면 https 붙이기
        if !text.lowercased().hasPrefix("http://") && !text.lowercased().hasPrefix("https://") {
            text = "https://" + text
        }

        // URLComponents로 검증 (도메인+스킴 필수)
        guard let comps = URLComponents(string: text),
              let scheme = comps.scheme,
              (scheme == "http" || scheme == "https"),
              comps.host != nil
        else {
            print("❌ Invalid URL:", text)
            return nil
        }

        return comps.url
    }
}
