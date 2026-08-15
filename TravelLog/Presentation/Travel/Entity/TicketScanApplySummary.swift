//
//  TicketScanApplySummary.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation

/// 티켓 스캔 결과가 폼에 반영된 뒤, 화면에 표시할 정보만 추려낸 요약값
struct TicketScanApplySummary {
    let departureCityName: String?
    let destinationCityName: String?
    let confidence: Double
    let notes: String?
}
