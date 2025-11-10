//
//  PhotoItemCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/10/25.
//

import UIKit
import SnapKit

final class PhotoItemCell: UICollectionViewCell {
    static let identifier = "PhotoItemCell"
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(imageView.snp.width) // ✅ 1:1 비율 유지
        }
        imageView.layer.cornerRadius = 10
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
    }

    func configure(with image: UIImage) {
        imageView.image = image
    }
}
