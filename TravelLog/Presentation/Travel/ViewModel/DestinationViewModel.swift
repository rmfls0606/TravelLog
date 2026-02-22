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
        private(set) var filteredCities: Driver<[City]>
        private(set) var isLoading: Driver<Bool>
    }
    
    func transform(input: Input) -> Output {
        let loadingRelay = BehaviorRelay<Bool>(value: false)
        let cities = input.searchCityText
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .distinctUntilChanged()
                    .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
                    .flatMapLatest { [weak self] query -> Driver<[City]> in
                        guard let self = self,
                              !query.isEmpty else {
                            loadingRelay.accept(false)
                            return .just([])
                        }
                        
                        loadingRelay.accept(true)

                        return self.fetchCitiesUseCase
                            .execute(query: query)
                            .do(onSuccess: { _ in
                                loadingRelay.accept(false)
                            }, onError: { _ in
                                loadingRelay.accept(false)
                            })
                            .asDriver(onErrorJustReturn: [])
                    }
                    .asDriver(onErrorJustReturn: [])
        
        return Output(filteredCities: cities,
                      isLoading: loadingRelay.asDriver()
        )
    }
}
