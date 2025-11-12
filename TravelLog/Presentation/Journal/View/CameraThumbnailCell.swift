//
//  CameraThumbnailCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/12/25.
//

import UIKit
import SnapKit

final class CameraThumbnailCell: UICollectionViewCell {
    
    static let identifier = "CameraThumbnailCell"
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "camera.fill")
        view.tintColor = .darkGray
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.backgroundColor = UIColor.systemGray5
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        contentView.addSubview(iconView)
        
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
