//
//  CityRepositoryImpl.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

final class CityRepositoryImpl: CityRepository {
    private let local: CityDataSource
    private let remote: CityRemoteDataSource
    
    init(local: CityDataSource, remote: CityRemoteDataSource) {
           self.local = local
           self.remote = remote
       }
    
    func searchLocal(query: String) -> Single<[City]> {
            local.search(query: query)
        }
        
        func searchRemote(query: String, sessionToken: String) -> Single<[City]> {
            remote.search(query: query, sessionToken: sessionToken)
        }
        
        func ensureStored(city: City) -> Single<Void> {
            local.fetchCity(by: city.cityId)
                .flatMap { existing in
                    if existing != nil {
                        return .just(())
                    } else {
                        return self.local.save(city: city)
                    }
                }
        }
        
        func increasePopularity(cityId: String) -> Single<Void> {
            local.incrementPopularity(cityId: cityId)
        }
}
