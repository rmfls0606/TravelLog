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
    
    func search(query: String) -> Single<[City]> {
        Single.create { single in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                single(.success([]))
                return Disposables.create()
            }
            
            self.functions.httpsCallable("searchCity")
                .call(["query": trimmed]) { result, error in
                    if let error = error {
                        single(.failure(error))
                        return
                    }
                    guard let data = result?.data as? [String: Any] else {
                        single(.success([]))
                        return
                    }
                    
                    guard
                        let cityId = data["cityId"] as? String,
                        let name = data["name"] as? String,
                        let country = data["country"] as? String,
                        let lat = data["lat"] as? Double,
                        let lng = data["lng"] as? Double
                    else {
                        single(.success([]))
                        return
                    }
                    
                    let city = City(
                        cityId: cityId,
                        name: name,
                        country: country,
                        lat: lat,
                        lng: lng,
                        imageUrl: data["imageUrl"] as? String
                    )
                    
                    single(.success([city]))
                }
            
            return Disposables.create()
        }
    }
}
