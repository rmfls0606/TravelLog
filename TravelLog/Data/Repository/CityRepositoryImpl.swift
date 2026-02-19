//
//  CityRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

final class CityRepositoryImpl: CityRepository {
    private let dataSource: CityDataSource
    
    init(dataSource: CityDataSource = FirebaseCityDataSource()) {
        self.dataSource = dataSource
    }
    
    func fetchCities(query: String) -> Single<[City]> {
        return dataSource.loadCities(query: query)
    }
    
    func createCities(query: String) -> Single<City> {
        return dataSource.createCity(query: query)
    }
}
