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
    private var loadTask: Task<Void, Never>?
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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        imageView.image = nil
        overlayView.isHidden = true
        checkMark.isHidden = true
    }
    
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
            make.size.equalTo(25)
        }
    }
    
    func updateSelectionState(_ isSelected: Bool) {
            checkMark.isHidden = !isSelected
            overlayView.isHidden = !isSelected
        }
    
    func applyThumbnailStream(_ stream: AsyncStream<UIImage?>) {
            loadTask = Task {
                var isFirst = true
                for await image in stream {
                    guard !Task.isCancelled else { return }
                    if isFirst {
                        imageView.image = image
                        isFirst = false
                    } else {
                        UIView.transition(with: imageView, duration: 0.15, options: .transitionCrossDissolve) {
                            self.imageView.image = image
                        }
                    }
                }
            }
        }
}
