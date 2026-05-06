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
    private enum Constants {
        static let browsePageSize = 30
        static let browseFetchLimit = 500
    }

    private let usesSectionHeader: Bool
    private let disposeBag = DisposeBag()
    private let fetchCitiesUseCase: FetchCitiesUseCaseImpl
    
    init(usesSectionHeader: Bool = true) {
        self.usesSectionHeader = usesSectionHeader
        let local = FirebaseCityDataSource()
        let remote = FunctionsCityRemoteDataSource(region: "us-central1")
        let repo = CityRepositoryImpl(local: local, remote: remote)
        
        self.fetchCitiesUseCase = FetchCitiesUseCaseImpl(repository: repo)
    }
    
    struct Input {
        let searchCityText: ControlProperty<String>
        let loadNextPage: Observable<Void>
    }
    
    struct Output {
        let state: Driver<SearchState>
        let items: Driver<[CityCellItem]>
    }
    
    func transform(input: Input) -> Output {
        let itemsRelay = BehaviorRelay<[CityCellItem]>(value: [])
        var browseCities: [City] = []
        var displayedBrowseCount = 0

        input.loadNextPage
            .withLatestFrom(input.searchCityText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { [usesSectionHeader] query in
                !usesSectionHeader && query.isEmpty
            }
            .bind(with: self) { owner, _ in
                guard !browseCities.isEmpty else { return }
                guard displayedBrowseCount < browseCities.count else { return }

                displayedBrowseCount = min(
                    displayedBrowseCount + Constants.browsePageSize,
                    browseCities.count
                )
                itemsRelay.accept(
                    Array(browseCities.prefix(displayedBrowseCount)).map { .city($0) }
                )
            }
            .disposed(by: disposeBag)
        
        let state = input.searchCityText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
            .flatMapLatest { [weak self] query -> Observable<SearchState> in
                guard let self else { return .just(.idle) }

                if query.isEmpty {
                    let hasExistingDefaultCities = !itemsRelay.value.isEmpty &&
                    itemsRelay.value.contains {
                        if case .city = $0 { return true }
                        return false
                    }

                    if !hasExistingDefaultCities && SimpleNetworkState.shared.isConnected {
                        itemsRelay.accept(Array(repeating: .skeleton, count: 5))
                    }

                    return Observable.just(.loading)
                        .concat(
                            (self.usesSectionHeader
                             ? self.fetchCitiesUseCase.fetchPopularCities(limit: 6)
                             : self.fetchCitiesUseCase.fetchCities(
                                country: "대한민국",
                                limit: Constants.browseFetchLimit
                             ))
                                .asObservable()
                                .map { cities -> SearchState in
                                    if self.usesSectionHeader {
                                        itemsRelay.accept(cities.map { .city($0) })
                                    } else {
                                        browseCities = cities
                                        displayedBrowseCount = min(
                                            Constants.browsePageSize,
                                            cities.count
                                        )
                                        itemsRelay.accept(
                                            Array(cities.prefix(displayedBrowseCount)).map { .city($0) }
                                        )
                                    }
                                    return cities.isEmpty ? .idle : .result
                                }
                                .catch { error in
                                    if case CitySearchError.offline = error {
                                        browseCities = []
                                        displayedBrowseCount = 0
                                        itemsRelay.accept([])
                                        return .just(.offline)
                                    }
                                    browseCities = []
                                    displayedBrowseCount = 0
                                    itemsRelay.accept([])
                                    return .just(.idle)
                                }
                        )
                }

                browseCities = []
                displayedBrowseCount = 0

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
