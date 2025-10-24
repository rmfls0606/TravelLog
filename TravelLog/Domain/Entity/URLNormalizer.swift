//
//  URLNormalizer.swift
//  TravelLog
//
//  Created by 이상민 on 10/25/25.
//

import Foundation

enum URLNormalizer {
    static func normalized(_ raw: String?) -> URL? {
        guard let text = raw, !text.isEmpty else { return nil }
        let pattern = "(https?://[\\S]+)|(www\\.[\\S]+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        if let match = regex?.firstMatch(in: text, range: NSRange(location: 0, length: text.count)) {
            let nsText = text as NSString
            let found = nsText.substring(with: match.range)
            if found.lowercased().hasPrefix("http") {
                return URL(string: found)
            } else {
                return URL(string: "https://" + found)
            }
        }
        return nil
    }
}
