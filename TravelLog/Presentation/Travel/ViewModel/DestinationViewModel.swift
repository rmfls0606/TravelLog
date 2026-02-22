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

enum SearchState {
    case idle
    case loading
    case empty
    case result([City])
}

final class DestinationViewModel {
    private let disposeBag = DisposeBag()
    private let fetchCitiesUseCase: FetchCitiesUseCaseImpl
    private let increasePopularityUseCase: IncreaseCityPopularityUseCase
    
    init() {
        let local = FirebaseCityDataSource()
        let remote = FunctionsCityRemoteDataSource(region: "us-central1")
        let repo = CityRepositoryImpl(local: local, remote: remote)
        
        self.fetchCitiesUseCase = FetchCitiesUseCaseImpl(repository: repo)
        self.increasePopularityUseCase = IncreaseCityPopularityUseCaseImpl(repository: repo)
    }
    
    struct Input {
        let searchCityText: ControlProperty<String>
    }
    struct Output {
        let state: Driver<SearchState>
        let cities: Driver<[City]>
    }
    
    func transform(input: Input) -> Output {
        let citiesRelay = BehaviorRelay<[City]>(value: [])

        let state = input.searchCityText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .flatMapLatest { [weak self] query -> Observable<SearchState> in
                
                guard let self = self else { return .just(.idle) }
                
                if query.isEmpty {
                    citiesRelay.accept([])
                    return .just(.idle)
                }
                
                return Observable.just(.loading)
                    .concat(
                        self.fetchCitiesUseCase
                            .execute(query: query)
                            .asObservable()
                            .map { cities in
                                citiesRelay.accept(cities)
                                return cities.isEmpty ? .empty : .result(cities)
                            }
                            .catchAndReturn(.empty)
                    )
            }
            .asDriver(onErrorJustReturn: .idle)
        
        return Output(
            state: state,
            cities: citiesRelay.asDriver()
        )
    }
}
