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
    
    func execute(query: String, sessionToken: String) -> Single<[City]> {
        //먼저 로컬 -> 없으면 원격 후보
        repository.searchLocal(query: query)
            .flatMap { cities in
                if !cities.isEmpty { return .just(cities) }
                return self.repository.searchRemote(query: query, sessionToken: sessionToken)
            }
    }
}
