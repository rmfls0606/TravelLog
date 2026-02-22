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
            .flatMap { cities in
                if !cities.isEmpty {
                    return .just(cities)
                }
                
                // 로컬에 없고, 오프라인이면 즉시 종료
                if !SimpleNetworkState.shared.isConnected {
                    return .error(CitySearchError.offline)
                }
                
                // 온라인일 때만 remote
                return self.repository.searchRemote(query: query)
            }
    }
}
