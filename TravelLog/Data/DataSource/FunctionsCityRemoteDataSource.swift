//
//  FunctionsCityRemoteDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/20/26.
//

import Foundation
import RxSwift
import FirebaseFunctions

final class FunctionsCityRemoteDataSource: CityRemoteDataSource {
    private let functions: Functions

    init(region: String = "us-central1") {
        self.functions = Functions.functions(region: region)
    }

    func search(query: String, sessionToken: String) -> Single<[City]> {
        Single.create { single in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                single(.success([]))
                return Disposables.create()
            }

            self.functions.httpsCallable("searchCity")
                .call([
                    "query": trimmed,
                    "sessionToken": sessionToken,
                    "language": "ko",
                    "limit": 10
                ]) { result, error in
                    if let error = error {
                        single(.failure(error))
                        return
                    }

                    guard
                        let root = result?.data as? [String: Any],
                        let arr = root["cities"] as? [[String: Any]]
                    else {
                        single(.success([]))
                        return
                    }

                    let cities: [City] = arr.compactMap { d in
                        guard
                            let cityId = d["cityId"] as? String,
                            let name = d["name"] as? String,
                            let country = d["country"] as? String,
                            let lat = d["lat"] as? Double,
                            let lng = d["lng"] as? Double
                        else { return nil }

                        return City(
                            cityId: cityId,
                            name: name,
                            country: country,
                            lat: lat,
                            lng: lng,
                            imageUrl: d["imageUrl"] as? String
                        )
                    }

                    single(.success(cities))
                }

            return Disposables.create()
        }
    }
}
