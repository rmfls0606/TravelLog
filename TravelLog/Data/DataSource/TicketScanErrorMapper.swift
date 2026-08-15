//
//  TicketScanErrorMapper.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation
import FirebaseFunctions

//MARK: - Firebase Functions/네트워크 에러를 도메인이 이해하는 TicketScanError로 변환하는 순수 로직
enum TicketScanErrorMapper {

    static func map(_ error: Error) -> TicketScanError {
        let nsError = error as NSError

        if isConnectivityError(nsError) {
            return .offline
        }

        if nsError.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidArgument:
                return .invalidImage
            case .failedPrecondition:
                return .refused
            case .resourceExhausted, .unavailable, .deadlineExceeded:
                return .serverBusy
            default:
                return .unknown
            }
        }

        return .unknown
    }

    private static func isConnectivityError(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else { return false }
        return error.code == NSURLErrorNotConnectedToInternet ||
            error.code == NSURLErrorNetworkConnectionLost ||
            error.code == NSURLErrorTimedOut ||
            error.code == NSURLErrorCannotFindHost ||
            error.code == NSURLErrorCannotConnectToHost ||
            error.code == NSURLErrorDNSLookupFailed
    }
}
