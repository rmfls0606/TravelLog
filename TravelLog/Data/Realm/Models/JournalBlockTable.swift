//
//  JournalBlockTable.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RealmSwift

// MARK: - Enum
enum JournalBlockType: String, CaseIterable, PersistableEnum {
    case text = "텍스트"
    case photo = "사진"
    case location = "장소"
    case link = "링크"
    case voice = "음성"
    
    var iconName: String {
        switch self {
        case .text: return "bubble.left"
        case .photo: return "camera"
        case .location: return "location"
        case .link: return "link"
        case .voice: return "waveform"
        }
    }
}

// MARK: - JournalBlockTable
final class JournalBlockTable: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var journalId: ObjectId
    @Persisted var type: JournalBlockType
    @Persisted var order: Int
    
    // Content
    @Persisted var text: String?
    @Persisted var imageURLs: List<String>
    @Persisted var latitude: Double?
    @Persisted var longitude: Double?
    @Persisted var placeName: String?
    @Persisted var linkURL: String?
    @Persisted var voiceURL: String?
    @Persisted var createdAt: Date = Date()
    
    // 역참조
    @Persisted(originProperty: "blocks") var journal: LinkingObjects<JournalTable>
    
    convenience init(
        journalId: ObjectId,
        type: JournalBlockType,
        order: Int,
        text: String? = nil,
        imageURLs: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        linkURL: String? = nil,
        voiceURL: String? = nil
    ) {
        self.init()
        self.journalId = journalId
        self.type = type
        self.order = order
        self.text = text
        self.imageURLs.append(objectsIn: imageURLs)
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.linkURL = linkURL
        self.voiceURL = voiceURL
        self.createdAt = Date()
    }
}
