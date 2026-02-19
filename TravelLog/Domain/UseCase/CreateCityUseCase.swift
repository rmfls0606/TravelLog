//
//  CreateCityUseCase.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import Foundation
import RxSwift

protocol CreateCityUseCase {
    func execute(query: String) -> Single<City>
}
