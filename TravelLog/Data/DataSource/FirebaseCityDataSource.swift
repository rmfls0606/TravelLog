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
    private let cacheTTL: TimeInterval = 10   // 5초는 너무 짧게 느껴질 수 있어서 10 추천
    private let workQueue = DispatchQueue(label: "city.search.queue", qos: .userInitiated)

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func rank(city: City, queryLower: String) -> Int {
        let name = normalized(city.name)
        let country = normalized(city.country)

        if name == queryLower { return 0 }
        if name.hasPrefix(queryLower) { return 1 }
        if name.contains(queryLower) { return 2 }
        if country == queryLower { return 3 }
        if country.hasPrefix(queryLower) { return 4 }
        return 5
    }

    func search(query: String) -> Single<[City]> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .just([]) }

        let lower = normalized(trimmed)

        //prefix 변화에 따른 캐시 정리 (엉뚱한 캐시가 남는 것 방지)
        //예: "인" -> "인천" -> "인" 반복 시 안전
        memoryCache.keys
            .filter { key in !key.hasPrefix(lower) && !lower.hasPrefix(key) }
            .forEach { memoryCache.removeValue(forKey: $0) }

        //memory cache hit
        if let entry = memoryCache[lower],
           Date().timeIntervalSince(entry.timestamp) < cacheTTL {
            return .just(entry.cities)
        }

        let end = lower + "\u{f8ff}"

        func asDouble(_ value: Any?) -> Double? {
            if let number = value as? NSNumber { return number.doubleValue }
            if let double = value as? Double { return double }
            if let int = value as? Int { return Double(int) }
            if let string = value as? String { return Double(string) }
            return nil
        }

        func decode(_ docs: [QueryDocumentSnapshot]) -> [City] {
            docs.compactMap { doc in
                let data = doc.data()
                let lat = asDouble(data["lat"])
                let lng = asDouble(data["lng"])
                guard
                    let name = data["name"] as? String,
                    let country = data["country"] as? String,
                    let lat,
                    let lng
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
            var byNameLower: [City] = []
            var byCountryLower: [City] = []
            var byNameLegacy: [City] = []
            var byCountryLegacy: [City] = []
            var firstError: Error?

            group.enter()
            db.collection(collection)
                .order(by: "nameLower")
                .start(at: [lower])
                .end(at: [end])
                .limit(to: pageLimit)
                .getDocuments(source: source) { snap, error in
                    defer { group.leave() }
                    if let error = error {
                        if source != .cache {
                            firstError = firstError ?? error
                        }
                        return
                    }
                    byNameLower = decode(snap?.documents ?? [])
                }

            group.enter()
            db.collection(collection)
                .order(by: "countryLower")
                .start(at: [lower])
                .end(at: [end])
                .limit(to: pageLimit)
                .getDocuments(source: source) { snap, error in
                    defer { group.leave() }
                    if let error = error {
                        if source != .cache {
                            firstError = firstError ?? error
                        }
                        return
                    }
                    byCountryLower = decode(snap?.documents ?? [])
                }

            // 하위호환: 과거 문서(nameLower/countryLower 미존재)도 prefix 검색에 포함
            group.enter()
            db.collection(collection)
                .order(by: "name")
                .start(at: [trimmed])
                .end(at: [trimmed + "\u{f8ff}"])
                .limit(to: pageLimit)
                .getDocuments(source: source) { snap, error in
                    defer { group.leave() }
                    if let error = error {
                        if source != .cache {
                            firstError = firstError ?? error
                        }
                        return
                    }
                    byNameLegacy = decode(snap?.documents ?? [])
                }

            group.enter()
            db.collection(collection)
                .order(by: "country")
                .start(at: [trimmed])
                .end(at: [trimmed + "\u{f8ff}"])
                .limit(to: pageLimit)
                .getDocuments(source: source) { snap, error in
                    defer { group.leave() }
                    if let error = error {
                        if source != .cache {
                            firstError = firstError ?? error
                        }
                        return
                    }
                    byCountryLegacy = decode(snap?.documents ?? [])
                }

            group.notify(queue: workQueue) {
                if let error = firstError {
                    completion(.failure(error))
                    return
                }

                let merged = mergeUnique(
                    mergeUnique(byNameLower, byCountryLower),
                    mergeUnique(byNameLegacy, byCountryLegacy)
                )
                let sorted = merged.sorted { lhs, rhs in
                    let lhsRank = self.rank(city: lhs, queryLower: lower)
                    let rhsRank = self.rank(city: rhs, queryLower: lower)
                    if lhsRank != rhsRank { return lhsRank < rhsRank }

                    let lhsPopularity = lhs.popularityCount ?? 0
                    let rhsPopularity = rhs.popularityCount ?? 0
                    if lhsPopularity != rhsPopularity { return lhsPopularity > rhsPopularity }

                    if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                completion(.success(Array(sorted.prefix(self.pageLimit))))
            }
        }

        return Single.create { single in
            var cancelled = false

            // 1) cache first
            runPrefixQueries(source: .cache) { cacheResult in
                if cancelled { return }
                switch cacheResult {
                case .success(let cached) where !cached.isEmpty:
                    // 캐시에 일부 결과만 있을 수 있어 서버 결과로 보강
                    // (예: 캐시 2개만 존재하면 그대로 고정되는 문제 방지)
                    if cached.count >= self.pageLimit || !SimpleNetworkState.shared.isConnected {
                        self.memoryCache[lower] = CacheEntry(cities: cached, timestamp: Date())
                        single(.success(cached))
                        return
                    }

                    runPrefixQueries(source: .default) { defaultResult in
                        if cancelled { return }
                        switch defaultResult {
                        case .success(let fresh) where !fresh.isEmpty:
                            self.memoryCache[lower] = CacheEntry(cities: fresh, timestamp: Date())
                            single(.success(fresh))
                        case .success:
                            self.memoryCache[lower] = CacheEntry(cities: cached, timestamp: Date())
                            single(.success(cached))
                        case .failure:
                            self.memoryCache[lower] = CacheEntry(cities: cached, timestamp: Date())
                            single(.success(cached))
                        }
                    }

                default:
                    if !SimpleNetworkState.shared.isConnected {
                        single(.success([]))
                        return
                    }
                    // 2) default fallback
                    runPrefixQueries(source: .default) { defaultResult in
                        if cancelled { return }
                        switch defaultResult {
                        case .success(let cities):
                            self.memoryCache[lower] = CacheEntry(cities: cities, timestamp: Date())
                            single(.success(cities))
                        case .failure(let error):
                            single(.failure(error))
                        }
                    }
                }
            }

            return Disposables.create {
                cancelled = true
            }
        }
    }

    func fetchCity(by cityId: String) -> Single<City?> { fatalError() }
    func save(city: City) -> Single<Void> { fatalError() }
    func incrementPopularity(cityId: String) -> Single<Void> { fatalError() }
}
