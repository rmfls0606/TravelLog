//
//  City.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import Foundation

struct City: Codable {
    let cityId: String
    
    let name: String
    let country: String
    
    let lat: Double
    let lng: Double
    let imageUrl: String?
    
    var popularityCount: Int?
}

enum CitySearchError: Error{
    case offline
}
