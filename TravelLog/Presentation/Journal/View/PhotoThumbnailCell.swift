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
    
    private let shimmerView: ShimmerView = {
        let view = ShimmerView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.isHidden = true
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
        contentView.addSubview(shimmerView)
        contentView.addSubview(imageView)
        imageView.addSubview(overlayView)
        imageView.addSubview(checkMark)
    }
    
    private func configureLayout(){
        shimmerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
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
    
    private func showShimmer(){
        shimmerView.startShimmering()
        imageView.isHidden = true
    }
    
    private func hideShimmer(){
        shimmerView.stopShimmering()
        imageView.isHidden = false
    }
    
    func updateSelectionState(_ isSelected: Bool) {
        checkMark.isHidden = !isSelected
        overlayView.isHidden = !isSelected
    }
    
    func applyThumbnailStream(immediateImage: UIImage?, stream: AsyncStream<UIImage?>) {
        
        //이전 로드 작업을 취소
        loadTask?.cancel()
        
        //즉시 로드할 이미지가 있는지 확인합니다.
        if let image = immediateImage{
            //이미지가 있으면
            imageView.image = image
            hideShimmer()
            loadTask = nil
        }else{
            //즉시 로드할 이미지가 없습니다.
            showShimmer()
            
            loadTask = Task {
                var isFirst = true
                for await image in stream {
                    guard !Task.isCancelled else { return }
                    if isFirst {
                        imageView.image = image
                        self.hideShimmer()
                        isFirst = false
                    } else {
                        self.imageView.image = image
                    }
                }
                
                if isFirst{
                    self.hideShimmer()
                }
            }
        }
    }
}
