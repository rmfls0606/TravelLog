//
//  FetchCitiesUseCaseImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

final class FetchCitiesUseCaseImpl: FetchCitiesUseCase {
    private let repository: CityRepository
    
    init(repository: CityRepository) {
        self.repository = repository
    }
    
    func execute(query: String) -> Single<[City]> {
        repository.searchLocal(query: query)
            .catch { error in
                // local 단계에서 연결 에러면 remote로 넘기지 않고 즉시 offline 처리
                if self.isConnectivityError(error) {
                    return .error(CitySearchError.offline)
                }
                return .error(error)
            }
            .flatMap { cities in
                if !cities.isEmpty {
                    return .just(cities)
                }

                // 오프라인이면 remote(functions) 재시도하지 않는다.
                if !SimpleNetworkState.shared.isConnected {
                    return .error(CitySearchError.offline)
                }

                // 로컬에 없으면 remote를 시도하고,
                // 실제 연결 에러일 때만 offline으로 매핑한다.
                return self.repository.searchRemote(query: query)
                    .catch { error in
                        if self.isConnectivityError(error) {
                            return .error(CitySearchError.offline)
                        }
                        return .error(error)
                    }
            }
    }

    private func isConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return nsError.code == NSURLErrorNotConnectedToInternet ||
            nsError.code == NSURLErrorNetworkConnectionLost ||
            nsError.code == NSURLErrorTimedOut ||
            nsError.code == NSURLErrorCannotFindHost ||
            nsError.code == NSURLErrorCannotConnectToHost ||
            nsError.code == NSURLErrorDNSLookupFailed
    }
}
