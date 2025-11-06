//
//  PhotoPageViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/5/25.
//

import UIKit
import PhotosUI
import SnapKit

final class PhotoPageViewController: UIPageViewController {
    
    var onDismissToIndex: ((Int) -> Void)? //현재 인덱스를 되돌려줄 클로저
    
    private let viewModel: PhotoPickerViewModel
    
    private var allAssets: [PHAsset]
    private var currentIndex: Int
    
    private let totalAssetCount: Int
    
    private let customNavigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = .black.withAlphaComponent(0.3)
        return view
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    init(viewModel: PhotoPickerViewModel, allAssets: [PHAsset], currentIndex: Int, totalCount: Int) {
        self.viewModel = viewModel
        self.allAssets = allAssets
        self.currentIndex = currentIndex
        self.totalAssetCount = totalCount
        
        let options: [UIPageViewController.OptionsKey: Any] = [
            .interPageSpacing: 32.0
        ]
        
        super.init(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: options
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        delegate = self
        dataSource = self
        
        view.backgroundColor = .black
        
        setupCustomBar()
        setupInitialPage()
        updateNavigationTitle()
        
    }
    
    private func setupCustomBar() {
        // PageVC의 view '위에' 바를 추가합니다.
        view.addSubview(customNavigationBar)
        customNavigationBar.addSubview(closeButton)
        customNavigationBar.addSubview(titleLabel)
        
        // 커스텀 바는 화면 상단에 Safe Area까지 차지
        customNavigationBar.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(44) // 표준 네비게이션 바 높이
        }
        
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalTo(customNavigationBar.snp.bottom).offset(-8)
            make.width.height.equalTo(30)
        }
        
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(closeButton.snp.centerY)
        }
    }
    
    @objc private func didTapCloseButton() {
        onDismissToIndex?(currentIndex)
        self.dismiss(animated: true)
    }
    
    private func setupInitialPage() {
        guard let initialVC = createPreviewController(at: currentIndex) else {
            dismiss(animated: true)
            return
        }
        
        setViewControllers([initialVC], direction: .forward, animated: false)
    }
    
    private func updateNavigationTitle() {
        self.titleLabel.text = "\(currentIndex + 1) / \(totalAssetCount)"
    }
    
    private func createPreviewController(at index: Int) -> PhotoPreviewViewController? {
        if index >= viewModel.numberOfItems() - 5 {
            viewModel.loadMoreAssetsIfNeeded()
        }
        
        guard let asset = viewModel.safeAsset(at: index) else {
               return nil
           }
        
        let previewVC = PhotoPreviewViewController(
            viewModel: self.viewModel,
            asset: asset,
            index: index
        )
        
        previewVC.onSingleTap = { [weak self] in
            self?.toggleCustomBar()
        }
        
        return previewVC
    }
    
    func toggleCustomBar() {
        let isHidden = customNavigationBar.alpha == 0
        UIView.animate(withDuration: 0.25) {
            self.customNavigationBar.alpha = isHidden ? 1 : 0
        }
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
        
        //페이징 트리거
        //남은 이미지가 적으면 ViewModel에 다음 페이지 요청
        if currentIndex >= viewModel.numberOfItems() - 5{
            viewModel.loadMoreAssetsIfNeeded()
        }
    }
}
