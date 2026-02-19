//
//  CityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import RxSwift

protocol CityDataSource{
    func search(query: String) -> Single<[City]>
    func fetchCity(by cityId: String) -> Single<City?>
    func save(city: City) -> Single<Void>
    func incrementPopularity(cityId: String) -> Single<Void>
}
