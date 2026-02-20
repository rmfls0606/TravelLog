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
    
    private let sessionTokenRelay = BehaviorRelay<String>(value: UUID().uuidString)

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
        //텍스트가 비면 새 세션 토큰 발급(새 검색 시작)
        input.searchCityText
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.isEmpty }
                    .distinctUntilChanged()
                    .subscribe(with: self) { owner, _ in
                        owner.sessionTokenRelay.accept(UUID().uuidString)
                    }
                    .disposed(by: disposeBag)
        
        let cities = Observable
                    .combineLatest(
                        input.searchCityText.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                        sessionTokenRelay.asObservable()
                    )
                    .debounce(.milliseconds(400), scheduler: MainScheduler.instance)
                    .distinctUntilChanged { $0.0 == $1.0 } // query 기준
                    .flatMapLatest { [fetchCitiesUseCase] (q, token) -> Observable<[City]> in
                        guard !q.isEmpty else { return .just([]) }
                        return fetchCitiesUseCase.execute(query: q, sessionToken: token)
                            .asObservable()
                            .catchAndReturn([])
                    }
                    .asDriver(onErrorJustReturn: [])
        
        let didSelectCity = input.selectCity
                    .flatMapLatest { [ensureStoredUseCase, increasePopularityUseCase] city -> Signal<Void> in
                        ensureStoredUseCase.execute(city: city)
                            .flatMap { increasePopularityUseCase.execute(cityId: city.cityId) }
                            .asSignal(onErrorSignalWith: .empty())
                    }
                    .do(onNext: { [sessionTokenRelay] _ in
                        //선택하면 세션 종료 -> 새 토큰 준비
                        sessionTokenRelay.accept(UUID().uuidString)
                    })
                    .asSignal(onErrorSignalWith: .empty())
        
        return Output(filteredCities: cities, didSelectCity: didSelectCity)
    }
}
