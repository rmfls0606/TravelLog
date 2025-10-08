//
//  CityRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

final class CityRepositoryImpl: CityRepository {
    private let dataSource: LocalCityDataSource
    
    init(dataSource: LocalCityDataSource = LocalCityDataSource()) {
        self.dataSource = dataSource
    }
    
    func fetchCities() -> Single<[City]> {
        return dataSource.loadCities()
    }
}
