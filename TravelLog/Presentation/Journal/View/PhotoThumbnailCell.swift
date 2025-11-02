//
//  PhotoThumbnailCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import SnapKit

final class PhotoThumbnailCell: UICollectionViewCell {
    static let identifier = "PhotoThumbnailCell"
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        view.isHidden = true
        return view
    }()
    
    private let checkMark: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "checkmark.circle.fill")
        view.tintColor = .systemGreen
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func configureHierarchy(){
        contentView.addSubview(imageView)
        imageView.addSubview(overlayView)
        imageView.addSubview(checkMark)
    }
    
    private func configureLayout(){
        imageView.snp.makeConstraints{ make in
            make.edges.equalToSuperview()
        }
        
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        checkMark.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(6)
            make.bottom.equalToSuperview().inset(6)
            make.size.equalTo(30)
        }
    }
    
    func configure(image: UIImage?, isSelected: Bool) {
        imageView.image = image
        overlayView.isHidden = !isSelected
        checkMark.isHidden = !isSelected
    }
}
