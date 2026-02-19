//
//  CityRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import Foundation
import RxSwift

protocol CityRepository {
    //로컬에서만 검색
    func searchLocal(query: String) -> Single<[City]>
    //로컬에 없으면 원격에서 후보 가져오기
    func searchRemote(query: String) -> Single<[City]>
    //사용자가 선택했을 때만: Firestore에 없으면 저장
    func ensureStored(city: City) -> Single<Void>
    //사용자가 선택했을 때만: 인기 카운트 증가
    func increasePopularity(cityId: String) -> Single<Void>
}
