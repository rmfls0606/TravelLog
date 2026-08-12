//
//  TicketScanResultMapper.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation

enum TicketScanResultMapper {

    enum MappingError: Error, Equatable {
        case invalidPayload
    }

    static func map(from dictionary: [String: Any]) throws -> TicketScanResult {
        guard
            let isTicket = dictionary["isTicket"] as? Bool,
            let confidence = dictionary["confidence"] as? Double
        else {
            throw MappingError.invalidPayload
        }

        return TicketScanResult(
            isTicket: isTicket,
            transport: mapTransport(dictionary["transport"] as? String),
            departureCity: dictionary["departureCity"] as? String,
            departureCountry: dictionary["departureCountry"] as? String,
            destinationCity: dictionary["destinationCity"] as? String,
            destinationCountry: dictionary["destinationCountry"] as? String,
            startDate: parseDate(
                dateString: dictionary["startDate"] as? String,
                timeString: dictionary["startTime"] as? String
            ),
            endDate: parseDate(
                dateString: dictionary["endDate"] as? String,
                timeString: dictionary["endTime"] as? String
            ),
            confidence: confidence,
            notes: dictionary["notes"] as? String
        )
    }

    //MARK: - 서버가 내려주는 "airplane"/"bus"/"train" 문자열을 앱의 Transport enum으로 매핑
    static func mapTransport(_ raw: String?) -> Transport? {
        switch raw {
        case "airplane":
            return .airplane
        case "bus":
            return .bus
        case "train":
            return .train
        default:
            return nil
        }
    }

    //MARK: - "YYYY-MM-DD" (+ 선택적 "HH:mm")를 기기 로컬 타임존 기준 Date로 변환
    static func parseDate(dateString: String?, timeString: String?) -> Date? {
        guard let dateString, !dateString.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        if let timeString, !timeString.isEmpty {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            if let date = formatter.date(from: "\(dateString) \(timeString)") {
                return date
            }
        }

        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}
