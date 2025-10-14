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
    
    let departureRelay = PublishRelay<CityTable>()
    let destinationRelay = PublishRelay<CityTable>()
    
    private let repository: TravelRepositoryType
    
    private let disposeBag = DisposeBag()
    
    init(repository: TravelRepositoryType = TravelRepository()) {
        self.repository = repository
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
        private(set) var saveError: Signal<String>
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
        
        let saveResult = input.createButtonTapped
            .withLatestFrom(Observable.combineLatest(
                departureRelay.compactMap { $0 },
                destinationRelay.compactMap { $0 },
                selectedDateRelay.compactMap { $0.start },
                selectedDateRelay.compactMap { $0.end },
                selectedTransportRelay
            ))
            .flatMapLatest { [weak self] (dep, dest, start, end, transport) -> Observable<Result<Void, Error>> in
                guard let self else { return .empty() }
                
                return self.repository.createTravel(
                    departure: dep,
                    destination: dest,
                    startDate: start,
                    endDate: end,
                    transport: transport
                )
                .andThen(Observable.just(Result<Void, Error>.success(())))
                .catch { error in
                    Observable.just(Result<Void, Error>.failure(error))
                }
            }
            .share()
        
        // 저장 성공 / 실패 처리
        let saveCompleted = saveResult
            .compactMap { if case .success = $0 { return () } else { return nil } }
            .asSignal(onErrorSignalWith: .empty())
        
        let saveError = saveResult
            .compactMap { result -> String? in
                if case let .failure(error) = result {
                    return error.localizedDescription
                }
                return nil
            }
            .asSignal(onErrorJustReturn: "저장 실패")
        
        return Output(
            selectedTransport: selectedTransportRelay.asDriver(),
            selectedDateRange: selectedDateRelay.asDriver(),
            showCalendar: showCalendar,
            saveCompleted: saveCompleted,
            saveError: saveError
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
