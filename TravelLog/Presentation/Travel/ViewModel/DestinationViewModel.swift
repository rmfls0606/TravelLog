//
//  DestinationViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift
import RxCocoa
import FirebaseFunctions

final class DestinationViewModel {
    private let disposeBag = DisposeBag()
    private let fetchCitiesUseCase = FetchCitiesUseCaseImpl()
    private let createCityUseCase = CreateCityUseCaseImpl()
    private let functions = Functions.functions(region: "us-central1")
    
    struct Input {
        let searchCityText: ControlProperty<String>
    }
    struct Output {
        private(set) var filteredCities: Driver<[City]>
    }
    
    func transform(input: Input) -> Output {
        let cities = input.searchCityText
            .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest { [weak self] query -> Observable<[City]> in
                guard let self = self,
                      !query.isEmpty else{ return .just([])
                }
                
                return self.fetchCitiesUseCase.execute(query: query)
                    .asObservable()
                    .flatMapLatest { cities -> Observable<[City]> in
                        if cities.isEmpty {
                            return self.createCityUseCase.execute(query: query)
                                .asObservable()
                                .flatMapLatest { _ in
                                    self.fetchCitiesUseCase.execute(query: query)
                                        .asObservable()
                                }
                        }
                        return .just(cities)
                    }
                    .catchAndReturn([])
            }
            .asDriver(onErrorJustReturn: [])
        
        
        return Output(
            filteredCities: cities
        )
    }
}
