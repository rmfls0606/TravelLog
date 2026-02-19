//
//  EnsureCityStoredUseCaseImpl.swift
//  TravelLog
//
//  Created by 이상민 on 2/20/26.
//

import RxSwift

protocol EnsureCityStoredUseCase{
    func execute(city: City) -> Single<Void>
}

final class EnsureCityStoredUseCaseImpl: EnsureCityStoredUseCase{
    private let repository: CityRepository
    
    init(repository: CityRepository) {
        self.repository = repository
    }
    
    func execute(city: City) -> Single<Void> {
        repository.ensureStored(city: city)
    }
}
