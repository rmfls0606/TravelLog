//
//  FirebaseCityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import FirebaseFunctions
import FirebaseFirestore
import RxSwift
import Foundation

final class FirebaseCityDataSource: CityDataSource{
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    
    func loadCities(query: String) -> Single<[City]> {
        Single.create { single in
            
            self.db.collection("cities")
                .getDocuments { snapshot, error in
                    
                    if let error = error {
                        single(.failure(error))
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        single(.success([]))
                        return
                    }
                    
                    let lowerQuery = query.lowercased()
                    
                    let cities: [City] = documents.compactMap { doc -> City? in
                        let data = doc.data()
                        
                        guard let name = data["name"] as? String,
                              let country = data["country"] as? String,
                              let lat = data["lat"] as? Double,
                              let lng = data["lng"] as? Double
                        else { return nil }
                        
                        if name.lowercased().contains(lowerQuery) ||
                            country.lowercased().contains(lowerQuery) {
                            
                            return City(
                                cityId: doc.documentID,
                                name: name,
                                country: country,
                                lat: lat,
                                lng: lng,
                                imageUrl: data["imageUrl"] as? String)
                        }
                        
                        return nil
                    }
                    
                    single(.success(cities))
                }
            
            return Disposables.create()
        }
    }
    
    func createCity(query: String) -> Single<City> {
        Single.create { single in
            
            self.functions
                .httpsCallable("searchCity")
                .call(["query": query]) { result, error in
                    
                    if let error = error {
                        single(.failure(error))
                        return
                    }
                    
                    guard
                        let data = result?.data as? [String: Any],
                        let name = data["name_ko"] as? String,
                        let country = data["country_ko"] as? String,
                        let lat = data["lat"] as? Double,
                        let lng = data["lng"] as? Double
                    else {
                        single(.failure(NSError(domain: "InvalidData", code: -1)))
                        return
                    }
                    
                    let city = City(
                        cityId: data["cityId"] as? String ?? UUID().uuidString,
                        name: name,
                        country: country,
                        lat: lat,
                        lng: lng,
                        imageUrl: data["imageUrl"] as? String
                    )
                    
                    single(.success(city))
                }
            
            return Disposables.create()
        }
    }
}
