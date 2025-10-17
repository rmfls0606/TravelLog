//
//  TripStatus.swift
//  TravelLog
//
//  Created by 이상민 on 10/17/25.
//

import UIKit

enum TripStatus{
    case planned
    case ongoing
    case completed
    
    var color: UIColor{
        switch self {
        case .planned:
            return .systemBlue.withAlphaComponent(0.8)
        case .ongoing:
            return .systemGreen.withAlphaComponent(0.8)
        case .completed:
            return .systemPurple.withAlphaComponent(0.8)
        }
    }
}
