//
//  TravelTable.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import Foundation
import RealmSwift

final class TravelTable: Object {
    @Persisted(primaryKey: true) var id: ObjectId

    // 핵심
    @Persisted var departure: CityTable? //출발 도시
    @Persisted var destination: CityTable? //도착 도시
    
    @Persisted var startDate: Date //출발일
    @Persisted var endDate: Date //여행 종료일
    
    @Persisted var transport: Transport.RawValue
    
    @Persisted var createdAt: Date //생성 일자
    @Persisted var updateAt: Date //업데이트 일자
    
    convenience init(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport,
        createdAt: Date,
        updateAt: Date
    ) {
        self.init()
        self.departure = departure
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.transport = transport.rawValue
        self.createdAt = createdAt
        self.updateAt = updateAt
    }
}
