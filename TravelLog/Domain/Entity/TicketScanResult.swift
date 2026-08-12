//
//  TicketScanResult.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation

struct TicketScanResult: Equatable {
    let isTicket: Bool
    let transport: Transport?

    let departureCity: String?
    let departureCountry: String?
    let destinationCity: String?
    let destinationCountry: String?

    let startDate: Date?
    let endDate: Date?

    let confidence: Double
    let notes: String?
}
