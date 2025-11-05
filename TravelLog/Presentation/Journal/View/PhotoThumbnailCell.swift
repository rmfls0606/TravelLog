//
//  PhotoThumbnailCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import PhotosUI
import SnapKit

final class PhotoThumbnailCell: UICollectionViewCell {
    static let identifier = "PhotoThumbnailCell"
    private var loadTask: Task<Void, Never>?
    
    private var currentAssetIdentifier: String?
    
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
    
    func configure(with asset: PHAsset, targetSize: CGSize, viewModel: PhotoPickerViewModel) {
        // 1. 셀의 고유 ID를 설정합니다.
        let assetIdentifier = asset.localIdentifier
        self.currentAssetIdentifier = assetIdentifier
        
        // 2. (캐시 히트) ViewModel의 '공유 캐시'를 '먼저' 확인합니다.
        if let cachedImage = viewModel.cacheManager.get(
            forKey: assetIdentifier
        ) {
            self.imageView.image = cachedImage
            self.hideShimmer()
            self.loadTask = nil // (이전 작업이 있다면 취소)
            
        } else {
            // (1) '즉시' 쉬머를 보여줍니다.
            showShimmer()
            
            // (2) ViewModel에 비동기 스트림을 요청합니다.
            let stream = viewModel.requestThumbnailStream(for: asset, targetSize: targetSize)
            
            // (3) 비동기 작업을 시작합니다.
            loadTask = Task {
                var isFirstImage = true
                for await image in stream {
                    // (4) 이 작업이 현재 셀의 작업이 맞는지 확인
                    guard self.currentAssetIdentifier == assetIdentifier, !Task.isCancelled else {
                        return
                    }
                    
                    if isFirstImage {
                        self.imageView.image = image
                        self.hideShimmer() // 저화질 이미지라도 받으면 즉시 쉬머 숨김
                        isFirstImage = false
                    } else {
                        self.imageView.image = image
                    }
                }
                
                // (스트림이 비어서 끝났을 경우, 쉬머 숨김)
                if isFirstImage {
                    self.hideShimmer()
                }
            }
        }
    }
}
