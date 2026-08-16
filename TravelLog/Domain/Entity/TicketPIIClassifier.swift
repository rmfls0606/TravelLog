//
//  TicketPIIClassifier.swift
//  TravelLog
//
//  Created by Claude on 8/16/26.
//

import Foundation
import CoreGraphics

/// Vision이 인식한 텍스트 블록 하나. boundingBox는 Vision 좌표계(0...1, 원점 좌하단) 기준.
struct TicketTextRegion {
    let text: String
    let boundingBox: CGRect
}

/// 티켓 사진 속 텍스트 중 여권번호·예약번호·생년월일·이름처럼 개인을 특정할 수 있는
/// 항목의 후보를 정규식/키워드 휴리스틱으로 골라내는 순수 로직.
///
/// 목적은 "완벽한 탐지"가 아니라 Claude로 사진을 보내기 전에 가릴 후보를 최대한
/// 넓게 잡아내는 1차 방어선이다. 놓치는 케이스가 있을 수 있어, 최종 확인은 사용자가
/// 마스킹 결과를 직접 보고 판단하는 미리보기 단계에서 이뤄진다.
enum TicketPIIClassifier {
    private static let nameKeywords = [
        "PASSENGER", "PASSENGER NAME", "NAME", "성명", "승객", "탑승객", "氏名", "姓名", "乘客",
    ]
    private static let dobKeywords = [
        "DOB", "DATE OF BIRTH", "BIRTH DATE", "생년월일", "生年月日", "出生日期",
    ]

    static func regionsToMask(in regions: [TicketTextRegion]) -> [CGRect] {
        var matched: [CGRect] = []

        for (index, region) in regions.enumerated() {
            let trimmed = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if isPassportNumberCandidate(trimmed)
                || isReservationCodeCandidate(trimmed)
                || isDateOfBirthCandidate(trimmed)
                || containsKeyword(trimmed, in: dobKeywords)
                || containsKeyword(trimmed, in: nameKeywords)
                || (index > 0 && containsKeyword(regions[index - 1].text, in: nameKeywords))
                || (index > 0 && containsKeyword(regions[index - 1].text, in: dobKeywords)) {
                matched.append(region.boundingBox)
            }
        }

        return matched
    }

    /// 여권번호 후보: 영문 1~2자 + 숫자 6~9자리 (예: M12345678, PM1234567)
    private static func isPassportNumberCandidate(_ text: String) -> Bool {
        let pattern = #"^[A-Za-z]{1,2}[0-9]{6,9}$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    /// 예약번호/PNR 후보: 영문+숫자 조합 6자리 (숫자만 있는 6자리는 흔한 값이라 제외)
    private static func isReservationCodeCandidate(_ text: String) -> Bool {
        guard text.range(of: #"^[A-Za-z0-9]{6}$"#, options: .regularExpression) != nil else {
            return false
        }
        let hasLetter = text.rangeOfCharacter(from: .letters) != nil
        let hasDigit = text.rangeOfCharacter(from: .decimalDigits) != nil
        return hasLetter && hasDigit
    }

    /// 생년월일 후보: YYYY-MM-DD, DD/MM/YYYY, DD.MM.YYYY 등 날짜 형식 텍스트
    private static func isDateOfBirthCandidate(_ text: String) -> Bool {
        let patterns = [
            #"^\d{4}[-.\/]\d{2}[-.\/]\d{2}$"#,
            #"^\d{2}[-.\/]\d{2}[-.\/]\d{4}$"#,
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private static func containsKeyword(_ text: String, in keywords: [String]) -> Bool {
        let upper = text.uppercased()
        return keywords.contains { upper.contains($0.uppercased()) }
    }
}
