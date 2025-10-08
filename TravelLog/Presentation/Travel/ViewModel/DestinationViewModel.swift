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
    private let fetchCitiesUseCase = FetchCitiesUseCaseImpl()
    
    struct Input {
        let searchCityText: ControlProperty<String>
    }
    struct Output {
        private(set) var filteredCities: Driver<[City]>
    }
    
    func transform(input: Input) -> Output {
        let cities = fetchCitiesUseCase.execute()
            .asDriver(onErrorJustReturn: [])
        
        let filteredCities = Driver
            .combineLatest(cities, input.searchCityText.asDriver()) { cities, query in
                let trimmed = query.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return cities }
                return cities.filter { $0.name.localizedCaseInsensitiveContains(trimmed) ||
                    $0.id.localizedCaseInsensitiveContains(trimmed)
                }
            }
        
        return Output(
            filteredCities: filteredCities
        )
    }
}
