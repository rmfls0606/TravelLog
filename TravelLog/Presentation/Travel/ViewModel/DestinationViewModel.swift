//
//  DestinationViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import RxSwift
import RxCocoa

final class DestinationViewModel {
    private let disposeBag = DisposeBag()
    private let fetchCitiesUseCase = FetchCitiesUseCaseImpl()
    
    struct Input { }
    struct Output {
        let cities: Driver<[City]>
    }
    
    func transform(input: Input) -> Output {
        let cities = fetchCitiesUseCase.execute()
            .asDriver(onErrorJustReturn: [])
        return Output(cities: cities)
    }
}
