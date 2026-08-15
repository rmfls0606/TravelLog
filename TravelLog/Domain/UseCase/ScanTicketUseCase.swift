//
//  ScanTicketUseCase.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation
import RxSwift

protocol ScanTicketUseCase {
    func execute(imageData: Data, mimeType: String) -> Single<TicketScanResult>
}

final class ScanTicketUseCaseImpl: ScanTicketUseCase {

    private let repository: TicketScanRepository

    init(repository: TicketScanRepository) {
        self.repository = repository
    }

    func execute(imageData: Data, mimeType: String) -> Single<TicketScanResult> {
        repository.scanTicket(imageData: imageData, mimeType: mimeType)
    }
}
