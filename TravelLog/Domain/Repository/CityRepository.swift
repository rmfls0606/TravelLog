//
//  CityRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

protocol CityRepository {
    func fetchCities(query: String) -> Single<[City]>
    func createCities(query: String) -> Single<City>
}
