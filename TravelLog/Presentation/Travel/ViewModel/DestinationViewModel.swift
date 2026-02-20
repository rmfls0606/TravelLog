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
    
    private let sessionTokenRelay = BehaviorRelay<String>(value: UUID().uuidString)

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
    }
    
    func transform(input: Input) -> Output {
        let cities = input.searchCityText
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .distinctUntilChanged()
                    .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
                    .flatMapLatest { [weak self] query -> Driver<[City]> in
                        guard let self = self,
                              !query.isEmpty else { return .just([]) }

                        return self.fetchCitiesUseCase
                            .execute(query: query,
                                     sessionToken: sessionTokenRelay.value)
                            .asDriver(onErrorJustReturn: [])
                    }
                    .asDriver(onErrorJustReturn: [])
        
        return Output(filteredCities: cities)
    }
}
