//
//  PhotoSkeletonCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import SnapKit

final class PhotoSkeletonCell: UICollectionViewCell {
    static let identifier = "PhotoSkeletonCell"
    
    private let shimmerView: ShimmerView = {
        let view = ShimmerView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        shimmerView.startShimmering()
    }
    
    func startShimmering() {
        shimmerView.startShimmering()
    }
    
    private func configureHierarchy() {
        contentView.addSubview(shimmerView)
    }
    
    private func configureLayout() {
        shimmerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
