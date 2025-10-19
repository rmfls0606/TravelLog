//
//  JournalTable.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RealmSwift

// MARK: - JournalTable
final class JournalTable: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var tripId: ObjectId
    @Persisted var blocks: List<JournalBlockTable>
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
    @Persisted var isSecret: Bool = false
    
    // 역참조
    @Persisted(originProperty: "journals") var travel: LinkingObjects<TravelTable>
    
    convenience init(tripId: ObjectId, date: Date, isSecret: Bool = false) {
        self.init()
        self.tripId = tripId
        self.isSecret = isSecret
        self.createdAt = date
        self.updatedAt = date
    }
}
