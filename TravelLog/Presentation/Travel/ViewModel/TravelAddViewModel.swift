//
//  TravelAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import RxSwift
import RxCocoa
import Foundation

struct transportItem{
    let transport: Transport
    let isSelected: Bool
}

final class TravelAddViewModel: BaseViewModel {
    let selectedDateRelay = BehaviorRelay<(start: Date?, end: Date?)>(value: (start: nil, end: nil))
    let selectedTransportRelay = BehaviorRelay<Transport>(value: .airplane)
    let departureRelay = PublishRelay<CityTable>()
    let destinationRelay = PublishRelay<CityTable>()
    
    private let repository: TravelRepositoryType
    
    private let disposeBag = DisposeBag()
    
    init(repository: TravelRepositoryType = TravelRepository()) {
        self.repository = repository
    }
    
    struct Input{
        let transportTapped: Observable<Transport>
        let createButtonTapped: ControlEvent<Void>
    }
    
    struct Output{
        private(set) var transportItems: Driver<[transportItem]>
        private(set) var selectedTransport: Driver<Transport>
        private(set) var selectedDaterange: Driver<(start: Date?, end: Date?)>
        private(set) var saveCompleted: Signal<Void>
        private(set) var saveError: Signal<String>
    }
    
    func transform(input: Input) -> Output {
        let selectedTransport = BehaviorRelay<Transport>(value: .airplane)
        
        input.transportTapped
            .bind(to: selectedTransport)
            .disposed(by: disposeBag)
        
        let transportItems = selectedTransport
            .map { selected in
                Transport.allCases.map{
                    transportItem(transport: $0, isSelected: $0 == selected)
                }
            }
            .asDriver(onErrorDriveWith: .empty())
        
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
            transportItems: transportItems,
            selectedTransport: selectedTransport.asDriver(),
            selectedDaterange: selectedDateRelay.asDriver(),
            saveCompleted: saveCompleted,
            saveError: saveError
        )
    }
}
