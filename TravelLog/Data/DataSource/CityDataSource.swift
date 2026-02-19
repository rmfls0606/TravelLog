//
//  CityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import RxSwift

protocol CityDataSource{
    func loadCities(query: String) -> Single<[City]>
    func createCity(query: String) -> Single<City>
}
