//
//  LocalPhotoPreviewViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/10/25.
//

import UIKit
import SnapKit

final class LocalPhotoPreviewViewController: UIViewController, UIScrollViewDelegate {

    // MARK: - Properties
    var onSingleTap: (() -> Void)?
    let index: Int
    private let image: UIImage
    
    // MARK: - UI
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        return scrollView
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        return iv
    }()
    
    private lazy var singleTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        tap.numberOfTapsRequired = 1
        return tap
    }()
    
    private lazy var doubleTapGesture: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didDoubleTapView(_:)))
        tap.numberOfTapsRequired = 2
        return tap
    }()
    
    // MARK: - Init
    init(image: UIImage, index: Int) {
        self.image = image
        self.index = index
        super.init(nibName: nil, bundle: nil)
        self.view.tag = index
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupTapGesture()
        imageView.image = image
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImageViewLayout(for: image)
    }

    // MARK: - Setup
    private func setupViews() {
        view.backgroundColor = .black
        scrollView.delegate = self
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        // ✅ contentLayoutGuide & frameLayoutGuide 원본 구조 유지
        imageView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupTapGesture() {
        view.addGestureRecognizer(singleTapGesture)
        view.addGestureRecognizer(doubleTapGesture)
        singleTapGesture.require(toFail: doubleTapGesture)
    }

    // MARK: - Actions
    @objc private func didTapView() {
        onSingleTap?()
    }

    @objc private func didDoubleTapView(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let targetScale: CGFloat = 2.0
            let location = gesture.location(in: imageView)
            let zoomRect = calculateZoomRect(for: targetScale, with: location)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }

    // MARK: - Zoom Logic
    private func calculateZoomRect(for scale: CGFloat, with center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.width = imageView.frame.size.width / scale
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImage()
    }

    // MARK: - Layout Logic
    private func updateImageViewLayout(for image: UIImage) {
        let scrollSize = scrollView.bounds.size
        guard scrollSize.width > 0 && scrollSize.height > 0 else { return }
        
        let imageRatio = image.size.width / image.size.height
        let viewRatio = scrollSize.width / scrollSize.height

        var width: CGFloat
        var height: CGFloat

        if imageRatio > viewRatio {
            width = scrollSize.width
            height = width / imageRatio
        } else {
            height = scrollSize.height
            width = height * imageRatio
        }

        imageView.frame = CGRect(
            x: (scrollSize.width - width) / 2,
            y: (scrollSize.height - height) / 2,
            width: width,
            height: height
        )
        scrollView.contentSize = imageView.frame.size
    }

    private func centerImage() {
        let boundsSize = scrollView.bounds.size
        var frameToCenter = imageView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }
}
