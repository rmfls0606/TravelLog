//
//  FetchCitiesUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

protocol FetchCitiesUseCase {
    //displayNameHint: 검색어와 별개로, 원격 결과가 없을 때 저장/표시에 쓸 한글 이름 힌트
    func execute(query: String, displayNameHint: String?) -> Single<[City]>
    func fetchCities(country: String, limit: Int) -> Single<[City]>
    func fetchPopularCities(limit: Int) -> Single<[City]>
}

extension FetchCitiesUseCase {
    func execute(query: String) -> Single<[City]> {
        execute(query: query, displayNameHint: nil)
    }
}
