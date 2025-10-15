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

    private let disposeBag = DisposeBag()
    
    private let fetchTripUseCase: FetchTripUseCase
    private let deleteTripUseCase: DeleteTripUseCase

    init(
        fetchTripUseCase: FetchTripUseCase = FetchTripUseCaseImpl(
            repository: TripRepositoryImpl()),
        deleteTripUseCase: DeleteTripUseCase = DeleteTripUseCaseImpl(
            repository: TripRepositoryImpl())
    ) {
        self.fetchTripUseCase = fetchTripUseCase
        self.deleteTripUseCase = deleteTripUseCase
    }
    
    struct Input {
        let viewWillAppear: Observable<Void>
        let tripDelete: ControlEvent<TravelTable>
    }

    struct Output {
        private(set) var tripsRelay: Driver<[TravelTable]>
        private(set) var toastRelay: Signal<String>
    }

    func transform(input: Input) -> Output {
        let tripsRelay = BehaviorRelay<[TravelTable]>(value: [])
        let toastRelay = PublishRelay<String>()

        let fetchStream = fetchTripUseCase.execute()
            .do(onError: { error in
                if let realmError = error as? RealmError{
                    toastRelay.accept(realmError.errorDescription ?? "데이터를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요.")
                }
                toastRelay.accept("데이터 처리 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.")
            })
            .catchAndReturn([])
            .distinctUntilChanged{ $0 == $1}
        
        input.viewWillAppear
            .flatMapLatest { _ in
                fetchStream
            }
            .bind(to: tripsRelay)
            .disposed(by: disposeBag)
        
        input.tripDelete
            .flatMapLatest { [weak self] trip -> Completable in
                guard let self else { return .empty() }
                return self.deleteTripUseCase.execute(trip: trip)
            }
            .subscribe(
                onError: { error in
                    if let realmError = error as? RealmError {
                        toastRelay.accept(realmError.errorDescription ?? "데이터를 삭제하는데 실패했습니다.\n잠시 후 다시 시도해주세요.")
                    } else {
                        toastRelay.accept("데이터 처리 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.")}
                }
            )
            .disposed(by: disposeBag)
            
        
        return Output(
            tripsRelay: tripsRelay.asDriver(),
            toastRelay: toastRelay.asSignal())
    }
}
