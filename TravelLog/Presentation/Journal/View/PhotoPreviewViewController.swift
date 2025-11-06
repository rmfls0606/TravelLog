//
//  PhotoPreviewViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import PhotosUI
import SnapKit

/// 단일 PHAsset을 고화질로 로드하고 줌(Zoom)할 수 있는 뷰 컨트롤러
final class PhotoPreviewViewController: UIViewController, UIScrollViewDelegate {
    var onSingleTap: (() -> Void)?
    // MARK: - Properties
    private let viewModel: PhotoPickerViewModel
    
    private let asset: PHAsset
    private let imageManager = PHImageManager.default()
    
    private let cacheManager = ThumbnailCacheManager.shared
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0 // 4배까지 확대
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true // 줌을 위해 필요
        return imageView
    }()
    
    // MARK: - Initializer
    
    init(viewModel: PhotoPickerViewModel, asset: PHAsset, index: Int) {
        self.viewModel = viewModel
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
        
        self.view.tag = index
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupTapGesture()
        
        if let cachedImage = cacheManager.get(forKey: asset.localIdentifier) {
            self.imageView.image = cachedImage
        }
        
        loadFullImage()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.backgroundColor = .black
        
        // 줌을 위한 Delegate 설정
        scrollView.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        // AutoLayout (SnapKit)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 줌을 사용하려면 imageView가 scrollView의 contentLayoutGuide를 꽉 채워야 함
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            // 너비와 높이 제약조건을 contentLayoutGuide와 동일하게 설정
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
    }
    
    // MARK: - Logic
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func didTapView() {
        onSingleTap?()
    }
    
    private func loadFullImage() {
        let targetSize = CGSize(
            width: self.view.bounds.width * UIScreen.main.scale,
            height: self.view.bounds.height * UIScreen.main.scale
        )
        
        // 2. ViewModel의 stream 함수를 사용합니다.
        //    (이 함수는 이제 NSCache를 조회하지 않고 PHImageManager 스트림만 반환합니다.)
        let stream = self.viewModel.requestPreviewStream(for: asset, targetSize: targetSize)
        
        // 3. AsyncStream을 처리하는 로직은 동일합니다.
        Task {
            var isFirstImage = true
            for await image in stream {
                guard !Task.isCancelled else { return }
                
                if isFirstImage {
                    // (스와이프 시) 빈 이미지뷰에 저화질을 채움
                    if self.imageView.image == nil {
                        self.imageView.image = image
                    }
                    isFirstImage = false
                } else {
                    self.imageView.image = image
                }
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    // 줌(Zoom) 기능을 위해 어떤 뷰를 확대/축소할지 알려줍니다.
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}
