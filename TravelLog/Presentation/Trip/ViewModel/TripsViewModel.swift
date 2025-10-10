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
    }

    struct Output {
        let trips: Driver<[TravelTable]>
    }
    private let reloadTrigger = PublishRelay<Void>()

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
        
        return Output(trips: tripsRelay.asDriver())
    }
    func deleteTrip(_ trip: TravelTable) {
            repository.deleteTravel(trip)
        reloadTrigger.accept(()) 
        }
}
