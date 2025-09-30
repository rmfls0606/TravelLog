//
//  TravelAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import RxSwift
import RxCocoa

struct transportItem{
    let transport: Transport
    let isSelected: Bool
}

final class TravelAddViewModel: BaseViewModel {
    
    private let disposeBag = DisposeBag()
    
    struct Input{
        let transportTapped: Observable<Transport>
    }
    
    struct Output{
        private(set) var transportItems: Driver<[transportItem]>
    }
    
    func transform(input: Input) -> Output {
        let selectedTransport = BehaviorRelay<Transport>(value: .airplane)
        
        input.transportTapped
            .bind(to: selectedTransport)
            .disposed(by: disposeBag)
        
        let transportItems = selectedTransport
            .map { selected in
                Transport.allCases
                    .map{
                        transportItem(transport: $0, isSelected: $0 == selected)
                    }
            }
            .asDriver(onErrorDriveWith: .empty())
        
        return Output(
            transportItems: transportItems
        )
    }
}
