//
//  PhotoPageViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/5/25.
//

import UIKit
import PhotosUI

final class PhotoPageViewController: UIPageViewController {
    
    private let viewModel: PhotoPickerViewModel
    
    private var allAssets: [PHAsset]
    private var currentIndex: Int
    
    init(viewModel: PhotoPickerViewModel, allAssets: [PHAsset], currentIndex: Int) {
        self.viewModel = viewModel
        self.allAssets = allAssets
        self.currentIndex = currentIndex
        
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        dataSource = self
        
        setupInitialPage()
        updateNavigationTitle()
        view.backgroundColor = .white
    }
    
    private func setupInitialPage() {
        guard let initialVC = createPreviewController(at: currentIndex) else {
            dismiss(animated: true)
            return
        }
        
        setViewControllers([initialVC], direction: .forward, animated: false)
    }
    
    private func updateNavigationTitle() {
        self.title = "\(currentIndex + 1) / \(allAssets.count)"
    }
    
    private func createPreviewController(at index: Int) -> PhotoPreviewViewController? {
        guard index >= 0 && index < allAssets.count else {
            return nil
        }
        
        let asset = allAssets[index]
        
        let previewVC = PhotoPreviewViewController(
            viewModel: self.viewModel,
            asset: asset,
            index: index
        )
        
//        previewVC.view.tag = index
        
        return previewVC
    }
}

extension PhotoPageViewController: UIPageViewControllerDataSource {
    // '이전' 페이지로 스와이프할 때 호출될 뷰 컨트롤러를 반환합니다.
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        let index = viewController.view.tag
        
        return createPreviewController(at: index - 1)
    }
    
    // '다음' 페이지로 스와이프할 때 호출될 뷰 컨트롤러를 반환합니다.
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        let index = viewController.view.tag
        
        return createPreviewController(at: index + 1)
    }
}

extension PhotoPageViewController: UIPageViewControllerDelegate {
    
    // 페이지 전환이 '완료'되었을 때 호출됩니다.
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        guard completed, let currentVC = pageViewController.viewControllers?.first else {
            return
        }
        
        self.currentIndex = currentVC.view.tag
        
        updateNavigationTitle()
    }
}
