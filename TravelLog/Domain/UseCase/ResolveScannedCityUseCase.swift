//
//  ResolveScannedCityUseCase.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation
import RxSwift

protocol ResolveScannedCityUseCase {
    func execute(cityName: String?, countryHint: String?, displayNameHint: String?) -> Single<City?>
}

//MARK: - 스캔된 도시 이름(+국가 힌트) 문자열을 기존 도시 검색 파이프라인을 통해 실제 City로 변환
final class ResolveScannedCityUseCaseImpl: ResolveScannedCityUseCase {

    private let fetchCitiesUseCase: FetchCitiesUseCase

    init(fetchCitiesUseCase: FetchCitiesUseCase) {
        self.fetchCitiesUseCase = fetchCitiesUseCase
    }

    func execute(cityName: String?, countryHint: String?, displayNameHint: String?) -> Single<City?> {
        guard let cityName else { return .just(nil) }

        let trimmed = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .just(nil) }

        return fetchCitiesUseCase.execute(query: trimmed, displayNameHint: displayNameHint)
            .map { candidates in
                ScannedCityMatcher.bestMatch(from: candidates, countryHint: countryHint)
            }
            // 도시 검색이 실패해도(오프라인 등) 전체 스캔 결과를 무효화하지 않고
            // 사용자가 수동으로 도시를 선택할 수 있도록 nil로 처리한다.
            .catchAndReturn(nil)
    }
}
