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

    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }

    required init?(coder: NSCoder) { fatalError() }
    
    private func configureHierarchy(){
        contentView.addSubview(imageView)
    }
    
    private func configureLayout(){
        imageView.snp.makeConstraints{ make in
            make.edges.equalToSuperview()
        }
    }

    private func configureView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    func configure(image: UIImage?) {
        imageView.image = image
    }
}
