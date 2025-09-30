//
//  BaseCardView.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import UIKit

class BaseCardView: BaseView {
    override func configureView() {
        backgroundColor = .white
        layer.cornerRadius = 20
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.systemGray5.cgColor
    }
}
