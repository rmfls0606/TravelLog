//
//  TravelAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import RxSwift
import RxCocoa
import Foundation

final class TravelAddViewModel: BaseViewModel {
    
    private(set) var selectedDateRelay = BehaviorRelay<(start: Date?, end: Date?)>(value: (nil, nil))
    
    private let departureRelay = PublishRelay<CityTable>()
    private let destinationRelay = PublishRelay<CityTable>()
    
    private let createTripUseCase: CreateTripUseCase
    
    private let disposeBag = DisposeBag()
    
    init(
        createTripUseCase: CreateTripUseCase = CreateTripUseCaseImpl(
            repository: TripRepositoryImpl()
        )
    ) {
        self.createTripUseCase = createTripUseCase
    }
    
    struct Input{
        let transportSelected: Observable<Transport>
        let dateSelected: Observable<(Date?, Date?)>
        let calendarTapped: Observable<Void>
        let createButtonTapped: ControlEvent<Void>
    }
    
    struct Output{
        private(set) var selectedTransport: Driver<Transport>
        private(set) var selectedDateRange: Driver<(start: Date?, end: Date?)>
        private(set) var showCalendar: Signal<Void>
        private(set) var saveCompleted: Signal<Void>
        private(set) var toastMessage: Signal<String>
    }
    
    func transform(input: Input) -> Output {
        let selectedTransportRelay = BehaviorRelay<Transport>(value: .airplane)
        
        input.transportSelected
            .bind(to: selectedTransportRelay)
            .disposed(by: disposeBag)
        
        input.dateSelected
            .map{(start: $0.0, end: $0.1)}
            .bind(to: selectedDateRelay)
            .disposed(by: disposeBag)
        
        let showCalendar = input.calendarTapped
            .asSignal(onErrorJustReturn: ())
        
        let combinedInputs: Observable<(CityTable, CityTable, Date, Date, Transport)> = Observable.combineLatest(
            departureRelay.compactMap { $0 },
            destinationRelay.compactMap { $0 },
            selectedDateRelay.compactMap { $0.start },
            selectedDateRelay.compactMap { $0.end },
            selectedTransportRelay
        )
        
        let createTrigger = input.createButtonTapped
            .withLatestFrom(combinedInputs)
        
        let saveResult: Observable<Result<Void, RealmError>> = createTrigger
            .flatMapLatest { [weak self] (dep, dest, start, end, transport) -> Observable<Result<Void, RealmError>> in
                guard let self else { return .empty() }
                
                // Realm 저장 로직 실행
                let createProcess: Observable<Result<Void, RealmError>> =
                self.createTripUseCase.execute(
                    departure: dep,
                    destination: dest,
                    startDate: start,
                    endDate: end,
                    transport: transport
                )
                .andThen(Observable.just(.success(())))
                .catch { error in
                    return Observable.just(.failure(.saveFailure))
                }
                
                return createProcess
            }
            .share()
        
        let saveCompleted = saveResult
            .compactMap {
                if case .success = $0 { return () }
                else{ return nil }
            }
            .asSignal(onErrorSignalWith: .empty())
        
        let toastMessage = saveResult
            .compactMap { result -> String? in
                if case let .failure(error) = result {
                    return error.errorDescription
                }
                return nil
            }
            .asSignal(onErrorJustReturn: "데이터 저장 중 문제가 발생했어요.\n잠시 후 다시 시도해주세요.")
        
        return Output(
            selectedTransport: selectedTransportRelay.asDriver(),
            selectedDateRange: selectedDateRelay.asDriver(),
            showCalendar: showCalendar,
            saveCompleted: saveCompleted,
            toastMessage: toastMessage
        )
    }
    
    func updateDateRange(range: (start: Date?, end: Date?)){
        selectedDateRelay.accept(range)
    }
    
    func updateDeparture(_ city: CityTable) {
        departureRelay.accept(city)
    }
    
    func updateDestination(_ city: CityTable) {
        destinationRelay.accept(city)
    }
}

