//
//  TripsViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RxCocoa

struct TripSummary{
    let trip: TravelTable
    let journalCount: Int
}

final class TripsViewModel: BaseViewModel {
    
    private let disposeBag = DisposeBag()
    
    private let fetchTripUseCase: FetchTripUseCase
    private let deleteTripUseCase: DeleteTripUseCase
    private let fetchJournalCountUseCase: FetchJournalCountUseCase
    
    init(
        fetchTripUseCase: FetchTripUseCase = FetchTripUseCaseImpl(
            repository: TripRepositoryImpl()),
        deleteTripUseCase: DeleteTripUseCase = DeleteTripUseCaseImpl(
            repository: TripRepositoryImpl()),
        fetchJournalCountUseCase: FetchJournalCountUseCase = FetchJournalCountUseCaseImpl(repository: JournalRepository())
    ) {
        self.fetchTripUseCase = fetchTripUseCase
        self.deleteTripUseCase = deleteTripUseCase
        self.fetchJournalCountUseCase = fetchJournalCountUseCase
    }

    
    struct Input {
        let viewWillAppear: Observable<Void>
        let tripDelete: ControlEvent<TripSummary>
    }
    
    struct Output {
        private(set) var tripsRelay: Driver<[TripSummary]>
        private(set) var toastRelay: Signal<String>
    }
    
    func transform(input: Input) -> Output {
        let tripsRelay = BehaviorRelay<[TripSummary]>(value: [])
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
            .flatMapLatest { [weak self] _ -> Observable<[TripSummary]> in
                guard let self = self else { return .empty() }
                
                return self.fetchTripUseCase.execute()
                    .flatMap { trips -> Observable<[TripSummary]> in
                        let countStreams = trips.map { trip in
                            self.fetchJournalCountUseCase.execute(tripId: trip.id)
                                .map { TripSummary(trip: trip, journalCount: $0) }
                                .asObservable()
                        }
                        return Observable.combineLatest(countStreams)
                    }
            }
            .bind(to: tripsRelay)
            .disposed(by: disposeBag)
        
        input.tripDelete
            .flatMapLatest { [weak self] summary -> Completable in
                guard let self else { return .empty() }
                return self.deleteTripUseCase.execute(trip: summary.trip)
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
