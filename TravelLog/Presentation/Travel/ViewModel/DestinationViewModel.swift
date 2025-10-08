//
//  DestinationViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift
import RxCocoa

final class DestinationViewModel {
    private let disposeBag = DisposeBag()
    private let repository = CityRepositoryImpl()
    
    struct Input {
        let searchCityText: ControlProperty<String>
    }
    struct Output {
        private(set) var filteredCities: Driver<[City]>
    }
    
    func transform(input: Input) -> Output {
        let cities = repository.fetchCities()
            .asObservable()
            .share(replay: 1)
        
        let filteredCities = Observable<[City]>
            .combineLatest(cities, input.searchCityText) { cities, query in
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return cities }
                return cities.filter { $0.name.localizedCaseInsensitiveContains(trimmed) ||
                    $0.id.localizedCaseInsensitiveContains(trimmed)
                }
            }
            .asDriver(onErrorJustReturn: [])
        
        return Output(
            filteredCities: filteredCities
        )
    }
}
