//
//  City.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import Foundation

struct City: Codable {
//    let id: String
//    let name: String
//    let region: String
//    let country: String
    
    let cityId: String
//    let placeId: String
    
    let name: String
    let country: String
    
    let lat: Double
    let lng: Double
    let imageUrl: String?
    
    var popularityCount: Int?
}
