//
//  JournalBlockTable.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
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
    
    var color: UIColor{
        switch self {
        case .text:
            return .systemBlue
        case .photo:
            return .systemPink
        case .location:
            return .green
        case .link:
            return .systemPurple
        case .voice:
            return .systemOrange
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
    
    @Persisted var linkTitle: String?
    @Persisted var linkDescription: String?
    @Persisted var linkImagePath: String?
    
    @Persisted var voiceURL: String?
    @Persisted var createdAt: Date
    @Persisted var metadataUpdatedAt: Date?
    @Persisted var fetchFailCount: Int = 0 //실패 회수 및 마지막 실패 시각 추가
    
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
        linkTitle: String? = nil,
        linkDescription: String? = nil,
        linkImagePath: String? = nil,
        metadataUpdatedAt: Date? = nil,
        fetchFailCount: Int = 0,
        voiceURL: String? = nil,
        createdAt: Date
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
        self.metadataUpdatedAt = metadataUpdatedAt
        self.voiceURL = voiceURL
        self.createdAt = createdAt
    }
}
