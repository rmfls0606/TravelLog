//
//  LinkPreviewEntity.swift
//  TravelLog
//
//  Created by 이상민 on 10/24/25.
//

import UIKit

final class LinkPreviewEntity {
    let url: String
    let title: String?
    let description: String?
    let imageFilename: String?
    
    init(url: String, title: String?, description: String?, imageFilename: String?) {
        self.url = url
        self.title = title
        self.description = description
        self.imageFilename = imageFilename
    }
}
