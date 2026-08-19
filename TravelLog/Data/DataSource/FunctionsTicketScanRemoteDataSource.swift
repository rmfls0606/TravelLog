//
//  FunctionsTicketScanRemoteDataSource.swift
//  TravelLog
//
//  Created by Claude on 8/9/26.
//

import Foundation
import RxSwift
import FirebaseFunctions

final class FunctionsTicketScanRemoteDataSource: TicketScanRemoteDataSource {

    private let functions: Functions

    init(region: String = "us-central1") {
        self.functions = Functions.functions(region: region)
    }

    func scan(image: Data, mimeType: String) -> Single<TicketScanResult> {

        Single.create { single in

            self.functions.httpsCallable("parseTicketImage")
                .call([
                    "imageBase64": image.base64EncodedString(),
                    "mimeType": mimeType
                ]) { result, error in

                    if let error = error {
                        single(.failure(TicketScanErrorMapper.map(error)))
                        return
                    }

                    guard
                        let root = result?.data as? [String: Any],
                        let rawResult = root["result"] as? [String: Any]
                    else {
                        single(.failure(TicketScanError.unknown))
                        return
                    }

                    do {
                        let scanResult = try TicketScanResultMapper.map(from: rawResult)
                        single(.success(scanResult))
                    } catch {
                        single(.failure(TicketScanError.unknown))
                    }
                }

            return Disposables.create()
        }
    }
}
