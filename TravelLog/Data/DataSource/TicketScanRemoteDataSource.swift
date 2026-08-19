//
//  TicketScanRemoteDataSource.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation
import RxSwift

protocol TicketScanRemoteDataSource {
    func scan(image: Data, mimeType: String) -> Single<TicketScanResult>
}
