//
//  TicketScanRepositoryImpl.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation
import RxSwift

final class TicketScanRepositoryImpl: TicketScanRepository {

    private let remote: TicketScanRemoteDataSource

    init(remote: TicketScanRemoteDataSource) {
        self.remote = remote
    }

    func scanTicket(imageData: Data, mimeType: String) -> Single<TicketScanResult> {
        remote.scan(image: imageData, mimeType: mimeType)
    }
}
