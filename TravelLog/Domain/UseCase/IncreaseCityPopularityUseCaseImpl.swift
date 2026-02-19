//
//  IncreaseCityPopularityUseCaseImpl.swift
//  TravelLog
//
//  Created by 이상민 on 2/20/26.
//

import RxSwift

protocol IncreaseCityPopularityUseCase{
    func execute(cityId: String) -> Single<Void>
}

final class IncreaseCityPopularityUseCaseImpl: IncreaseCityPopularityUseCase{
    private let repository: CityRepository
    
    init(repository: CityRepository) {
        self.repository = repository
    }
    
    func execute(cityId: String) -> Single<Void> {
        repository.increasePopularity(cityId: cityId)
    }
}
