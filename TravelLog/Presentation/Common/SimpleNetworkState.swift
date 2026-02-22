//
//  SimpleNetworkState.swift
//  TravelLog
//
//  Created by 이상민 on 2/23/26.
//

import Network
import RxSwift
import RxCocoa

final class SimpleNetworkState{
    static let shared = SimpleNetworkState()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "search.network.monitor")
    private let relay = BehaviorRelay<Bool>(value: true)
    
    var isConnected: Bool { relay.value }
    var isConnectedDriver: Driver<Bool> { relay.asDriver() }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.relay.accept(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }
}
