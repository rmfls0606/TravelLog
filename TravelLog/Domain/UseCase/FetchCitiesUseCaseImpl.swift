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
    
    init(repository: CityRepository = CityRepositoryImpl()) {
        self.repository = repository
    }
    
    func execute() -> Single<[City]> {
        repository.fetchCities()
    }
}
