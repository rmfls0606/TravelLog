//
//  CreateCityUseCaseImpl.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import Foundation
import RxSwift

final class CreateCityUseCaseImpl: CreateCityUseCase{
    private let repository: CityRepository
    
    init(repository: CityRepository = CityRepositoryImpl()) {
        self.repository = repository
    }
    
    func execute(query: String) -> Single<City> {
        repository.createCities(query: query)
    }
}
