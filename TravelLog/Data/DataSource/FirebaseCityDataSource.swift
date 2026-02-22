//
//  FirebaseCityDataSource.swift
//  TravelLog
//
//  Created by 이상민 on 2/19/26.
//

import FirebaseFirestore
import RxSwift
import Foundation

final class FirebaseCityDataSource: CityDataSource {
    private let db = Firestore.firestore()
    private let collection = "cities"
    private let pageLimit = 20
    
    private struct CacheEntry {
        let cities: [City]
        let timestamp: Date
    }
    
    private var memoryCache: [String: CacheEntry] = [:]
    private let cacheTTL: TimeInterval = 5
    
    func search(query: String) -> Single<[City]> {
        Single.create { single in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                single(.success([]))
                return Disposables.create()
            }
            
            let lower = trimmed.lowercased()
            if let entry = self.memoryCache[lower],
               Date().timeIntervalSince(entry.timestamp) < self.cacheTTL {
                single(.success(entry.cities))
                return Disposables.create()
            }
            let end = lower + "\u{f8ff}"
            
            func decode(_ docs: [QueryDocumentSnapshot]) -> [City] {
                docs.compactMap { doc in
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
                }
            }
            
            func mergeUnique(_ a: [City], _ b: [City]) -> [City] {
                var map: [String: City] = [:]
                a.forEach { map[$0.cityId] = $0 }
                b.forEach { map[$0.cityId] = $0 }
                return Array(map.values)
            }
            
            func runPrefixQueries(source: FirestoreSource, completion: @escaping (Result<[City], Error>) -> Void) {
                let group = DispatchGroup()
                
                var byName: [City] = []
                var byCountry: [City] = []
                var firstError: Error?
                
                // nameLower prefix
                group.enter()
                self.db.collection(self.collection)
                    .order(by: "nameLower")
                    .start(at: [lower])
                    .end(at: [end])
                    .limit(to: self.pageLimit)
                    .getDocuments(source: source) { snap, error in
                        defer { group.leave() }
                        if let error = error { firstError = firstError ?? error; return }
                        byName = decode(snap?.documents ?? [])
                    }
                
                // countryLower prefix
                group.enter()
                self.db.collection(self.collection)
                    .order(by: "countryLower")
                    .start(at: [lower])
                    .end(at: [end])
                    .limit(to: self.pageLimit)
                    .getDocuments(source: source) { snap, error in
                        defer { group.leave() }
                        if let error = error { firstError = firstError ?? error; return }
                        byCountry = decode(snap?.documents ?? [])
                    }
                
                group.notify(queue: .main) {
                    if let error = firstError {
                        completion(.failure(error))
                        return
                    }
                    let merged = mergeUnique(byName, byCountry)
                        .sorted { ($0.popularityCount ?? 0) > ($1.popularityCount ?? 0) }
                    completion(.success(Array(merged.prefix(self.pageLimit))))
                }
            }
            
            // 1) cache first (빠르게)
            runPrefixQueries(source: .cache) { cacheResult in
                switch cacheResult {
                    
                case .success(let cachedCities):
                    if !cachedCities.isEmpty {
                        
                        // 메모리 캐시에 저장
                        self.memoryCache[lower] = CacheEntry(
                            cities: cachedCities,
                            timestamp: Date()
                        )
                        
                        single(.success(cachedCities))
                        return
                    }
                    
                    // cache 비었으면 default 재시도
                    runPrefixQueries(source: .default) { defaultResult in
                        switch defaultResult {
                        case .success(let cities):
                            
                            // 메모리 캐시에 저장
                            self.memoryCache[lower] = CacheEntry(
                                cities: cities,
                                timestamp: Date()
                            )
                            
                            single(.success(cities))
                            
                        case .failure(let error):
                            single(.failure(error))
                        }
                    }
                    
                case .failure:
                    // cache 실패해도 default 시도
                    runPrefixQueries(source: .default) { defaultResult in
                        switch defaultResult {
                        case .success(let cities):
                            
                            self.memoryCache[lower] = CacheEntry(
                                cities: cities,
                                timestamp: Date()
                            )
                            
                            single(.success(cities))
                            
                        case .failure(let error):
                            single(.failure(error))
                        }
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    // 나머지 fetch/save/increment은 그대로 두면 됨
    func fetchCity(by cityId: String) -> Single<City?> { /* 기존 코드 */ fatalError() }
    func save(city: City) -> Single<Void> { /* 기존 코드 */ fatalError() }
    func incrementPopularity(cityId: String) -> Single<Void> { /* 기존 코드 */ fatalError() }
}
