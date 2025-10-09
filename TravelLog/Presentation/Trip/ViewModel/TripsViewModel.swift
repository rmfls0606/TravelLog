//
//  TripsViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RxCocoa

final class TripsViewModel: BaseViewModel {

    struct Input {
        let viewWillAppear: Observable<Void>
        let tripSelected: Observable<TravelTable>
    }

    struct Output {
        let trips: Driver<[TravelTable]>
        let selectedTrip: Signal<TravelTable>
    }

    private let repository: TravelRepositoryType
    private let disposeBag = DisposeBag()
    private let tripsRelay = BehaviorRelay<[TravelTable]>(value: [])

    init(repository: TravelRepositoryType = TravelRepository()) {
        self.repository = repository
    }

    func transform(input: Input) -> Output {
        input.viewWillAppear
            .flatMapLatest { [weak self] _ -> Observable<[TravelTable]> in
                guard let self else { return .empty() }
                return self.repository.fetchTrips()
            }
            .bind(to: tripsRelay)
            .disposed(by: disposeBag)
        
        return Output(
            trips: tripsRelay.asDriver(),
            selectedTrip: input.tripSelected.asSignal(onErrorSignalWith: .empty())
        )
    }
}
