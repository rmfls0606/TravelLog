//
//  ReusableViewProtocol.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import UIKit

protocol ReusableViewProtocol{
    static var identifier: String { get }
}

extension UITableViewCell: ReusableViewProtocol{
    static var identifier: String{
        return String(describing: self)
    }
}

