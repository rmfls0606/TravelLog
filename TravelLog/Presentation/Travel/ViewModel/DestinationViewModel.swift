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
    private let ensureStoredUseCase: EnsureCityStoredUseCase
    private let increasePopularityUseCase: IncreaseCityPopularityUseCase
    
    init() {
        // 간단 DI (나중에 Coordinator/DIContainer로 빼면 됨)
        let local = FirebaseCityDataSource()
        let remote = FunctionsCityRemoteDataSource(region: "us-central1")
        let repo = CityRepositoryImpl(local: local, remote: remote)
        
        self.fetchCitiesUseCase = FetchCitiesUseCaseImpl(repository: repo)
        self.ensureStoredUseCase = EnsureCityStoredUseCaseImpl(repository: repo)
        self.increasePopularityUseCase = IncreaseCityPopularityUseCaseImpl(repository: repo)
    }
    
    struct Input {
        let searchCityText: ControlProperty<String>
        let selectCity: ControlEvent<City>
    }
    struct Output {
        private(set) var filteredCities: Driver<[City]>
        private(set) var didSelectCity: Signal<Void>
    }
    
    func transform(input: Input) -> Output {
        let cities = input.searchCityText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .flatMapLatest { [fetchCitiesUseCase] q -> Driver<[City]> in
                guard !q.isEmpty else { return .just([]) }
                return fetchCitiesUseCase.execute(query: q)
                    .asDriver(onErrorJustReturn: [])
            }
            .asDriver(onErrorJustReturn: [])
        
        let didSelectCity = input.selectCity
            .flatMapLatest { [ensureStoredUseCase, increasePopularityUseCase] city -> Signal<Void> in
                ensureStoredUseCase.execute(city: city)
                    .flatMap { increasePopularityUseCase.execute(cityId: city.cityId) }
                    .asSignal(onErrorSignalWith: .empty())
            }
            .asSignal(onErrorSignalWith: .empty())
        
        return Output(filteredCities: cities, didSelectCity: didSelectCity)
    }
}
