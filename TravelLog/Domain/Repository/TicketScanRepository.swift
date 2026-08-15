//
//  TicketScanRepository.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation
import RxSwift

protocol TicketScanRepository {
    func scanTicket(imageData: Data, mimeType: String) -> Single<TicketScanResult>
}
