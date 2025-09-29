//
//  Transport.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import Foundation

enum Transport: String, CaseIterable{
    case airplane = "항공"
    case train = "기차"
    case bus = "버스"
    case car = "자동차"
    
    var iconName: String {
        switch self {
        case .airplane: 
            return "airplane.departure"
        case .train:    
            return "tram.fill"
        case .bus:
            return "bus.fill"
        case .car:   
            return "car.fill"
        }
    }
}
