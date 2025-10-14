//
//  GradientStyle.swift
//  TravelLog
//
//  Created by 이상민 on 10/14/25.
//

import UIKit

//앱 전체에서 재사용 가능한 그라데이션 스타일 정의
enum GradientStyle{
    case bluePurple
    case custom([UIColor])
    
    var colors: [UIColor]{
        switch self {
        case .bluePurple:
            return [
                UIColor(red: 90/255, green: 140/255, blue: 255/255, alpha: 1),
                UIColor(red: 130/255, green: 80/255, blue: 255/255, alpha: 1)
            ]
        case .custom(let colors):
            return colors
        }
    }
}
