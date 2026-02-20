//
//  CityRemoteDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/20/26.
//

import RxSwift

protocol CityRemoteDataSource{
    //원격 후보 조회
    func search(query: String, sessionToken: String) -> Single<[City]>
}
