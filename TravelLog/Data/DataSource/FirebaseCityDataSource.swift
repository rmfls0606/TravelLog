//
//  FirebaseCityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import FirebaseFirestore
import RxSwift
import Foundation

final class FirebaseCityDataSource: CityDataSource{
    private let db = Firestore.firestore()
    private let collection = "cities"
    
    func search(query: String) -> Single<[City]> {
        Single.create { single in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                single(.success([]))
                return Disposables.create()
            }
            
            let lower = trimmed.lowercased()
            let end = lower + "\u{f8ff}"
            
            self.db.collection(self.collection)
                .order(by: "nameLower")
                .start(at: [lower])
                .end(at: [end])
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    if let error = error {
                        single(.failure(error))
                        return
                    }
                    
                    let cities: [City] =  snapshot?.documents.compactMap { doc in
                        let data = doc.data()
                        
                        guard
                            let name = data["name"] as? String,
                            let country = data["country"] as? String,
                            let lat = data["lat"] as? Double,
                            let lng = data["lng"] as? Double
                        else { return nil }
                        
                        var city = City(
                            cityId: doc.documentID,
                            name: name,
                            country: country,
                            lat: lat,
                            lng: lng,
                            imageUrl: data["imageUrl"] as? String
                        )
                        city.popularityCount = data["popularityCount"] as? Int
                        return city
                    } ?? []
                    
                    single(.success(cities))
                }
            
            return Disposables.create()
        }
    }
    
    func fetchCity(by cityId: String) -> Single<City?> {
        Single.create { single in
            self.db.collection(self.collection)
                .document(cityId)
                .getDocument { snapshot, error in
                    if let error = error {
                        single(.failure(error))
                        return
                    }
                    guard let data = snapshot?.data() else {
                        single(.success(nil))
                        return
                    }
                    guard
                        let name = data["name"] as? String,
                        let country = data["country"] as? String,
                        let lat = data["lat"] as? Double,
                        let lng = data["lng"] as? Double
                    else {
                        single(.success(nil))
                        return
                    }
                    
                    var city = City(
                        cityId: cityId,
                        name: name,
                        country: country,
                        lat: lat,
                        lng: lng,
                        imageUrl: data["imageUrl"] as? String
                    )
                    city.popularityCount = data["popularityCount"] as? Int
                    single(.success(city))
                }
            return Disposables.create()
        }
    }
    
    func save(city: City) -> Single<Void> {
        Single.create { single in
            let ref = self.db.collection(self.collection).document(city.cityId)
            let payload: [String: Any] = [
                "cityId": city.cityId,
                "name": city.name,
                "country": city.country,
                "lat": city.lat,
                "lng": city.lng,
                "imageUrl": city.imageUrl as Any,
                "updatedAt": Date().timeIntervalSince1970,
                "popularityCount": FieldValue.increment(Int64(0)) // 없으면 0으로 유지
            ]
            ref.setData(payload, merge: true) { error in
                if let error = error {
                    single(.failure(error))
                } else {
                    single(.success(()))
                }
            }
            return Disposables.create()
        }
    }
    
    func incrementPopularity(cityId: String) -> Single<Void> {
        Single.create { single in
            let ref = self.db.collection(self.collection).document(cityId)
            ref.setData(
                ["popularityCount": FieldValue.increment(Int64(1)),
                 "updatedAt": Date().timeIntervalSince1970],
                merge: true
            ) { error in
                if let error = error {
                    single(.failure(error))
                } else {
                    single(.success(()))
                }
            }
            
            return Disposables.create()
        }
    }
}
