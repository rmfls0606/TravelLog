//
//  LocalCityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

//import Foundation
//import RxSwift
//
//final class LocalCityDataSource: CityDataSource{
//    func loadCities(query: String = "") -> Single<[City]> {
//        Single.create { single in
//            guard let url = Bundle.main.url(forResource: "Korean_cities", withExtension: "json"),
//                  let data = try? Data(contentsOf: url),
//                  let cities = try? JSONDecoder().decode([City].self, from: data) else {
//                single(.failure(NSError(domain: "NoData", code: -1)))
//                return Disposables.create()
//            }
//            single(.success(cities))
//            return Disposables.create()
//        }
//    }
//}
