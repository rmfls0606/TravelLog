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

enum CityCellItem {
    case skeleton
    case city(City)
}

enum SearchState {
    case idle
    case loading
    case empty
    case result
    case offline
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
        let items: Driver<[CityCellItem]>
    }
    
    func transform(input: Input) -> Output {
        let itemsRelay = BehaviorRelay<[CityCellItem]>(value: [])
        
        let state = input.searchCityText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
            .flatMapLatest { [weak self] query -> Observable<SearchState> in
                guard let self else { return .just(.idle) }

                if query.isEmpty {
                    itemsRelay.accept([])
                    return .just(.idle)
                }

                let hasExistingResults = !itemsRelay.value.isEmpty &&
                itemsRelay.value.contains {
                    if case .city = $0 { return true }
                    return false
                }
                
                // 첫 검색일 때만 skeleton
                if !hasExistingResults && SimpleNetworkState.shared.isConnected {
                    itemsRelay.accept(Array(repeating: .skeleton, count: 5))
                }

                return Observable.just(.loading)
                    .concat(
                        self.fetchCitiesUseCase.execute(query: query)
                            .asObservable()
                            .map { cities -> SearchState in
                                if cities.isEmpty {
                                    itemsRelay.accept([])
                                    return .empty
                                } else {
                                    itemsRelay.accept(cities.map { .city($0) })
                                    return .result
                                }
                            }
                            .catch { error in
                                if case CitySearchError.offline = error {
                                    itemsRelay.accept([])
                                    return .just(.offline)
                                }
                                itemsRelay.accept([])
                                return .just(.empty)
                            }
                    )
            }
            .asDriver(onErrorJustReturn: .idle)
        
        return Output(
            state: state,
            items: itemsRelay.asDriver()
        )
    }
}
