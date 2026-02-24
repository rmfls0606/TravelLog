//
//  CityTable.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import Foundation
import RealmSwift

final class CityTable: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    
    @Persisted var name: String // 도시명 (예: 파리)
    @Persisted var nameEn: String // 영어 도시명 (예: 파리)
    @Persisted var country: String // 나라명 (예: 프랑스)
    @Persisted var continent: String // 대륙명 (예: 유럽)
    
    @Persisted var iataCode: String? // 공항 코드 (CDG 등)
    @Persisted var latitude: Double // 위도
    @Persisted var longitude: Double // 경도
    @Persisted var cityDocId: String? // Firestore cities document id
    
    @Persisted var imageURL: String? // 도시 대표 이미지
    @Persisted var localImageFilename: String? // 오프라인용 로컬 이미지 파일명
    @Persisted var popularityCount: Int // 이미지 선택 카운트
    @Persisted var lastUpdated: Date = Date() // 마지막 갱신일
    
    // 역참조
    @Persisted(originProperty: "departure") var asDeparture: LinkingObjects<TravelTable>
    @Persisted(originProperty: "destination") var asDestination: LinkingObjects<TravelTable>
    
    convenience init(
        name: String,
        nameEn: String,
        country: String,
        continent: String,
        iataCode: String? = nil,
        latitude: Double = 0,
        longitude: Double = 0,
        popularityCount: Int = 0,
        cityDocId: String? = nil,
        imageURL: String? = nil,
        localImageFilename: String? = nil,
    ) {
        self.init()
        self.name = name
        self.nameEn = nameEn
        self.country = country
        self.continent = continent
        self.iataCode = iataCode
        self.latitude = latitude
        self.longitude = longitude
        self.popularityCount = popularityCount
        self.cityDocId = cityDocId
        self.imageURL = imageURL
        self.localImageFilename = localImageFilename
    }
}

extension CityTable {
    convenience init(from city: City) {
        self.init()
        self.name = city.name
        self.nameEn = city.name
        self.country = city.country
        self.continent = "Asia"
        self.iataCode = nil
        self.latitude = city.lat
        self.longitude = city.lng
        self.cityDocId = city.cityId
        self.imageURL = city.imageUrl
        self.localImageFilename = nil
        self.popularityCount = city.popularityCount ?? 0
    }
}
