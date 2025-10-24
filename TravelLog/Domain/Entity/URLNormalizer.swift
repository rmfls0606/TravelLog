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

        let components = text.split(separator: " ").map(String.init)
        guard let first = components.first(where: { $0.contains(".") }) else { return nil }

        var candidate = first.replacingOccurrences(of: " ", with: "")
        
        //대소문자 구분 없는 도메인 규격화를 위해 소문자화
        candidate = candidate.lowercased()

        if candidate.hasPrefix("http") {
            return URL(string: candidate)
        } else {
            return URL(string: "https://" + candidate)
        }
    }
}
