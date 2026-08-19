//
//  CityRemoteDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/20/26.
//

import RxSwift

protocol CityRemoteDataSource{
    //원격 후보 조회 (displayNameHint: 검색어와 별개로 저장/표시에 쓸 한글 이름 힌트)
    func search(query: String, displayNameHint: String?) -> Single<[City]>
}

extension CityRemoteDataSource {
    func search(query: String) -> Single<[City]> {
        search(query: query, displayNameHint: nil)
    }
}
