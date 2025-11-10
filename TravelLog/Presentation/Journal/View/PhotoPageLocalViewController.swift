//
//  PhotoPageLocalViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/10/25.
//

import UIKit
import SnapKit

final class PhotoPageLocalViewController: UIPageViewController {
    
    var onDismissToIndex: ((Int) -> Void)?
    private var images: [UIImage]
    private var currentIndex: Int
    
    private let customNavigationBar = UIView()
    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    
    init(images: [UIImage], currentIndex: Int) {
        self.images = images
        self.currentIndex = currentIndex
        
        let options: [UIPageViewController.OptionsKey: Any] = [
            .interPageSpacing: 24.0
        ]
        
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: options)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        delegate = self
        dataSource = self
        
        setupCustomBar()
        setupInitialPage()
        updateTitle()
    }
    
    private func setupCustomBar() {
        customNavigationBar.backgroundColor = .black.withAlphaComponent(0.3)
        view.addSubview(customNavigationBar)
        customNavigationBar.addSubview(closeButton)
        customNavigationBar.addSubview(titleLabel)
        
        customNavigationBar.snp.makeConstraints {
            $0.top.horizontalEdges.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(44)
        }
        
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().inset(8)
            $0.size.equalTo(30)
        }
        
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.snp.makeConstraints {
            $0.centerY.equalTo(closeButton)
            $0.centerX.equalToSuperview()
        }
    }
    
    @objc private func closeTapped() {
        onDismissToIndex?(currentIndex)
        dismiss(animated: true)
    }
    
    private func setupInitialPage() {
        guard let vc = createPreview(at: currentIndex) else { return }
        setViewControllers([vc], direction: .forward, animated: false)
    }
    
    private func updateTitle() {
        titleLabel.text = "\(currentIndex + 1) / \(images.count)"
    }
    
    private func createPreview(at index: Int) -> UIViewController? {
        guard index >= 0, index < images.count else { return nil }
        let vc = LocalPhotoPreviewViewController(image: images[index], index: index)
        vc.onSingleTap = { [weak self] in self?.toggleCustomBar() }
        return vc
    }
    
    func toggleCustomBar() {
        UIView.animate(withDuration: 0.25) {
            self.customNavigationBar.alpha = self.customNavigationBar.alpha == 0 ? 1 : 0
        }
    }
}

extension PhotoPageLocalViewController: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        let idx = viewController.view.tag
        return createPreview(at: idx - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        let idx = viewController.view.tag
        return createPreview(at: idx + 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let currentVC = pageViewController.viewControllers?.first else { return }
        currentIndex = currentVC.view.tag
        updateTitle()
    }
}
