//
//  PhotoPickerViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import SnapKit
import PhotosUI

final class PhotoPickerViewController: UIViewController {
    
    private enum PanMode{
        case none, selecting, scrolling
    }
    
    private enum AutoScrollDirection {
        case none, up, down
    }
    
    private let viewModel = PhotoPickerViewModel()
    private var panMode: PanMode = .none
    
    private let maxAutoScrollSpeed: CGFloat = 15.0 // 가장자리에 닿았을 때 최대 속도
    private let minAutoScrollSpeed: CGFloat = 2.0  // 핫존에 막 진입했을 때 최소 속도
    private let hotZoneHeight: CGFloat = 80.0      // 핫존의 높이
    
    /// 자동 스크롤 타이머입니다. (Timer보다 부드러운 CADisplayLink 사용)
    private var autoScrollLink: CADisplayLink?
    
    /// 현재 자동 스크롤 방향을 저장합니다.
    private var autoScrollDirection: AutoScrollDirection = .none
    
    private var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
        let itemWidth = (UIScreen.main.bounds.width - (spacing * 2)) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        
        collectionView.isPrefetchingEnabled = true
        collectionView.register(PhotoThumbnailCell.self,
                                forCellWithReuseIdentifier: PhotoThumbnailCell.identifier)
        collectionView.register(PhotoPickerHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: PhotoPickerHeaderView.identifier)
        return collectionView
    }()
    
    private lazy var dismissButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(didTapLeftBarButton))
        return button
    }()
    
    private lazy var allSelectButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "전체선택", style: .plain, target: self, action: #selector(didTapLeftBarButton))
        return button
    }()
    
    private lazy var selectButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: "선택", style: .plain, target: self, action: #selector(didTapSelect))
        return button
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, PHAsset>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureLayout()
        configureView()
        configureBind()
        Task{
            await viewModel.checkPermission()
        }
    }
    
    private func configureHierarchy(){
        view.addSubview(collectionView)
    }
    
    private func configureLayout(){
        collectionView.snp.makeConstraints { make in make.top.horizontalEdges.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }
    }
    
    private lazy var pan: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer()
        gesture.minimumNumberOfTouches = 1
        gesture.cancelsTouchesInView = true
        return gesture
    }()
    
    private func configureView(){
        title = "최근 항목"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = dismissButton
        navigationItem.rightBarButtonItem = selectButton
        collectionView.delegate = self
        collectionView.dataSource = self
        
        pan.addTarget(self, action: #selector(handlePanSelection(_:)))
        pan.delegate = self
        collectionView.addGestureRecognizer(pan)
    }
    
    private func configureBind() {
        viewModel.onSelectionModeChanged = { [weak self] isSelecting in
            guard let self = self else { return }
            self.selectButton.title = isSelecting ? "취소" : "선택"
            self.collectionView.allowsMultipleSelection = isSelecting
            
            if isSelecting{
                self.navigationItem.leftBarButtonItem = self.allSelectButton
            }else{
                self.navigationItem.leftBarButtonItem = self.dismissButton
                
                for visibleCell in self.collectionView.visibleCells {
                    if let cell = visibleCell as? PhotoThumbnailCell {
                        cell.updateSelectionState(false)
                    }
                }
            }
        }
        
        viewModel.onAssetsChanged = { [weak self] indexPaths in
            guard let self = self else { return }
            
            if let newIndexPaths = indexPaths{
                self.collectionView.performBatchUpdates({
                    self.collectionView.insertItems(at: newIndexPaths)
                }, completion: { _ in
                    self.viewModel.didFinishUpdatingUI()
                })
            }else{
                
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    self.viewModel.loadMoreAssetsIfNeeded()
                }
                self.viewModel.didFinishUpdatingUI()
                
                self.collectionView.reloadData()
                
                CATransaction.commit()
            }
        }
        
        viewModel.onSelectAllToggled = { [weak self] isAllSelected in
            guard let self else { return }
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoThumbnailCell else { continue }
                let asset = viewModel.asset(at: indexPath)
                cell.updateSelectionState(viewModel.isSelected(asset.localIdentifier))
            }
        }
        
        viewModel.onPermissionDenied = { [weak self] in
            let alert = UIAlertController(title: "권한 필요",
                                          message: "사진 접근 권한이 필요합니다. 설정에서 허용해주세요.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "이동", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }))
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            self?.present(alert, animated: true)
        }
        
        viewModel.onSelectionUpdated = { [weak self] updates in
            guard let self else { return }
            for (id, isSelected) in updates {
                if let index = self.viewModel.loadedAssets.firstIndex(where: { $0.localIdentifier == id }),
                   let cell = self.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? PhotoThumbnailCell {
                    cell.updateSelectionState(isSelected)
                }
            }
        }
    }
    
    @objc
    private func didTapSelect(){
        viewModel.toggleSelectionMode()
    }
    
    @objc
    private func didTapRemoveAllSelectedAsset(){
        viewModel.clearSelections()
    }
    
    @objc
    private func didTapLeftBarButton(){
        if viewModel.isSelectionMode{
            viewModel.toggleSelectAll()
        }else{
            dismiss(animated: true)
        }
    }
    
    @objc
    private func handlePanSelection(_ gesture: UIPanGestureRecognizer) {
        guard viewModel.isSelectionMode else { return }
        
        guard panMode == .selecting else { return }
        
        let location = gesture.location(in: collectionView)
        let indexPath = collectionView.indexPathForItem(at: location)
        
        switch gesture.state {
        case .began:
            if let index = indexPath?.item {
                viewModel.beginRangeSelection(at: index)
            }
            
        case .changed:
            if let index = indexPath?.item {
                viewModel.updateRangeSelection(to: index)
            }
            checkAutoScroll(at: location)
            
        case .ended, .cancelled, .failed:
            // 드래그 끝날 때, 마지막 위치로 한 번 더 update 후 end 호출
            if let index = indexPath?.item {
                viewModel.updateRangeSelection(to: index)
            }
            viewModel.endRangeSelection()
            panMode = .none //다음 팬을 위해 초기화
            stopAutoScroll()
            
        default:
            break
        }
    }
    
    
    /// 손가락 위치를 확인하여 자동 스크롤을 시작/중지합니다. (collectionView 좌표계 기준)
    private func checkAutoScroll(at location: CGPoint) {
        let bounds = collectionView.bounds
        
        // 핫존의 Y 좌표를 계산합니다.
        let topHotZoneY = bounds.minY + hotZoneHeight
        let bottomHotZoneY = bounds.maxY - hotZoneHeight
        
        if location.y < topHotZoneY {
            autoScrollDirection = .up
            startAutoScroll()
        } else if location.y > bottomHotZoneY {
            autoScrollDirection = .down
            startAutoScroll()
        } else {
            // 핫존에 없으면 타이머를 '중지'합니다.
            stopAutoScroll()
        }
    }
    
    /// 자동 스크롤 타이머(CADisplayLink)를 시작합니다.
    private func startAutoScroll() {
        guard autoScrollLink == nil else { return } // 이미 실행 중이면 중복 실행 방지
        
        let link = CADisplayLink(target: self, selector: #selector(handleAutoScrollTick))
        link.add(to: .main, forMode: .default)
        self.autoScrollLink = link
    }
    
    /// 자동 스크롤 타이머를 중지하고 리셋합니다.
    private func stopAutoScroll() {
        guard autoScrollLink != nil else { return }
        autoScrollLink?.invalidate()
        autoScrollLink = nil
        autoScrollDirection = .none
    }
    
    /// (매우 중요) CADisplayLink가 매 프레임마다 호출하는 함수입니다. (비례 속도 적용됨)
    @objc private func handleAutoScrollTick() {
        // 1. 방향이 없으면 멈춤 (stopAutoScroll()이 호출된 경우)
        guard autoScrollDirection != .none else {
            stopAutoScroll()
            return
        }
        
        // 2. 현재 손가락 위치 다시 가져오기
        let location = pan.location(in: collectionView)
        let bounds = collectionView.bounds
        
        // 3. 핫존 범위 정의
        let topHotZoneEndY = bounds.minY + hotZoneHeight
        let bottomHotZoneStartY = bounds.maxY - hotZoneHeight
        
        var speed: CGFloat = 0.0
        
        // 4. '비례' 속도 계산
        if autoScrollDirection == .up && location.y < topHotZoneEndY {
            // --- 상단 핫존 ---
            let distanceIntoZone = topHotZoneEndY - location.y
            let intensity = min(1.0, max(0.0, distanceIntoZone / hotZoneHeight)) // 0.0 ~ 1.0
            speed = (intensity * (maxAutoScrollSpeed - minAutoScrollSpeed)) + minAutoScrollSpeed
            
        } else if autoScrollDirection == .down && location.y > bottomHotZoneStartY {
            // --- 하단 핫존 ---
            let distanceIntoZone = location.y - bottomHotZoneStartY
            let intensity = min(1.0, max(0.0, distanceIntoZone / hotZoneHeight)) // 0.0 ~ 1.0
            speed = (intensity * (maxAutoScrollSpeed - minAutoScrollSpeed)) + minAutoScrollSpeed
            
        } else {
            // 핫존을 벗어남
            stopAutoScroll()
            return
        }
        
        // 5. 스크롤 적용
        var newOffset = collectionView.contentOffset
        if autoScrollDirection == .up {
            newOffset.y -= speed
        } else {
            newOffset.y += speed
        }
        
        // 6. 범위 제한
        let maxOffset = collectionView.contentSize.height - collectionView.bounds.height
        newOffset.y = max(0, min(newOffset.y, maxOffset))
        
        // 7. 스크롤이 실제로 일어났을 때만 적용
        if collectionView.contentOffset.y != newOffset.y {
            collectionView.contentOffset = newOffset
            collectionView.layoutIfNeeded()
            
            // 8. ViewModel 업데이트 (가장자리 셀 기준)
            let visibleBounds = collectionView.bounds
            let pointAtEdge: CGPoint
            if autoScrollDirection == .up {
                pointAtEdge = CGPoint(x: visibleBounds.midX, y: visibleBounds.minY + 1)
            } else {
                pointAtEdge = CGPoint(x: visibleBounds.midX, y: visibleBounds.maxY - 1)
            }
            
            if let indexPath = collectionView.indexPathForItem(at: pointAtEdge) {
                viewModel.updateRangeSelection(to: indexPath.item)
            }
        }
    }
}

extension PhotoPickerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfItems()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoThumbnailCell.identifier, for: indexPath) as? PhotoThumbnailCell else {
            return UICollectionViewCell()
        }
        
        let asset = viewModel.asset(at: indexPath)
        let isSelected = viewModel.isSelected(asset.localIdentifier)
        cell.updateSelectionState(isSelected)
        
        // AsyncStream 기반 안전한 이미지 로딩
        let scale = UIScreen.main.scale
        let itemSize = (collectionView.bounds.width - 4) / 3
        let targetSize = CGSize(width: itemSize * scale, height: itemSize * scale)
        
        cell.configure(with: asset, targetSize: targetSize, viewModel: viewModel)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: PhotoPickerHeaderView.identifier, for: indexPath) as? PhotoPickerHeaderView else {
            return UICollectionReusableView()
        }
        
        if viewModel.isLimitedAccess{
            header.onSelectMore = { [weak self] in
                guard let self = self else { return }
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
            }
            
            header.onOpenSetting = {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            
            return header
        }else{
            header.isHidden = true
            return header
        }
    }
}

extension PhotoPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.isSelectionMode{
            let asset = viewModel.asset(at: indexPath)
            viewModel.toggleSelection(for: asset.localIdentifier)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoThumbnailCell {
                let isSelected = viewModel.isSelected(asset.localIdentifier)
                cell.updateSelectionState(isSelected)
            }
        }else{
            let tappedIndex = indexPath.item
            let allLoadedAssets = viewModel.loadedAssets
            
            let totalCount = viewModel.totalAssetCount
            
            let pageVC = PhotoPageViewController(
                viewModel: self.viewModel,
                allAssets: allLoadedAssets,
                currentIndex: tappedIndex,
                totalCount: totalCount
            )
            
            pageVC.modalPresentationStyle = .fullScreen
            self.present(pageVC, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.isSelectionMode else { return }
        let asset = viewModel.asset(at: indexPath)
        viewModel.toggleSelection(for: asset.localIdentifier)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoThumbnailCell {
            let isSelected = viewModel.isSelected(asset.localIdentifier)
            cell.updateSelectionState(isSelected)
        }
    }
}

extension PhotoPickerViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        guard viewModel.isLimitedAccess else { return .zero }
        
        // 안전하게 헤더뷰 인스턴스 생성 후 높이 계산
        let fittingWidth = collectionView.bounds.width
        let headerView = PhotoPickerHeaderView(frame: CGRect(x: 0, y: 0, width: fittingWidth, height: 0))
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        
        // 콘텐츠 사이즈 계산
        let targetSize = CGSize(width: fittingWidth, height: UIView.layoutFittingCompressedSize.height)
        let height = headerView.systemLayoutSizeFitting(targetSize).height
        
        return CGSize(width: fittingWidth, height: height)
    }
}

extension PhotoPickerViewController: UICollectionViewDataSourcePrefetching{
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let indexs = indexPaths.map(\.item)
        let scale = UIScreen.main.scale
        let itemSize = (collectionView.bounds.width - 4) / 3
        let targetSize = CGSize(width: itemSize * scale, height: itemSize * scale)
        
        viewModel.prefetchImages(for: indexs, targetSize: targetSize)
        
        if let maxIndex = indexs.max(), maxIndex >= viewModel.numberOfItems() - 30{
            viewModel.loadMoreAssetsIfNeeded()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let indexs = indexPaths.map(\.item)
        let scale = UIScreen.main.scale
        let itemSize = (collectionView.bounds.width - 4) / 3
        let targetSize = CGSize(width: itemSize * scale, height: itemSize * scale)
        viewModel.cancelPrefetch(for: indexs, targetSize: targetSize)
    }
}

extension PhotoPickerViewController: UIScrollViewDelegate{
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let maxIndex = collectionView.indexPathsForVisibleItems.map(\.item).max() else { return }
        if maxIndex >= viewModel.numberOfItems() - 30 {
            viewModel.loadMoreAssetsIfNeeded()
        }
    }
}

extension PhotoPickerViewController: UIGestureRecognizerDelegate{
    //스크롤 vs 드래그 선택 구분
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == pan else { return true }
        
        let velocity = pan.velocity(in: collectionView)
        let absX = abs(velocity.x)
        let absY = abs(velocity.y)
        
        guard viewModel.isSelectionMode else {
            panMode = .none
            return false
        }
        
        //방향 결정
        if absX > absY{
            panMode = .selecting //수평 -> 선택 전용
            return true
        }else{
            panMode = .scrolling //수직 -> 스크롤
            return false
        }
    }
    
    //collectionView 스크롤 제스처와 동시 인식 허용
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if panMode == .selecting,
           otherGestureRecognizer == collectionView.panGestureRecognizer{
            return false
        }
        return true
    }
}
