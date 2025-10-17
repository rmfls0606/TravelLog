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
            return .systemBlue
        case .ongoing:
            return .systemGreen
        case .completed:
            return .systemPink
        }
    }
}
