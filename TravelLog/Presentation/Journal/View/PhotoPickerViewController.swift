//
//  PhotoPickerViewController.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import UIKit
import SnapKit
import Photos

final class PhotoPickerViewController: UIViewController {
    
    private let viewModel = PhotoPickerViewModel()
    private var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
        let itemWidth = (UIScreen.main.bounds.width - (spacing * 2)) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(PhotoThumbnailCell.self, forCellWithReuseIdentifier: PhotoThumbnailCell.identifier)
        return collectionView
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
    
    private func configureView(){
        title = "최근 항목"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = selectButton
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func configureBind() {
        viewModel.onSelectionModeChanged = { [weak self] isSelecting in
            self?.selectButton.title = isSelecting ? "취소" : "선택"
            self?.collectionView.allowsMultipleSelection = isSelecting
        }
        
        viewModel.onAssetsChanged = { [weak self] _ in
            self?.collectionView.reloadData()
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
    }
    
    @objc
    private func didTapSelect(){
        viewModel.toggleSelectionMode()
    }
    
    @objc
    private func didTapRemoveAllSelectedAsset(){
        viewModel.clearSelections()
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
        Task {
            let scale = UIScreen.main.scale
            let itemSize = (collectionView.bounds.width - 4) / 3
            let size = CGSize(width: itemSize * scale, height: itemSize * scale)
            let image = await viewModel.requestThumbnail(for: asset, targetSize: size)
            let isSelected = viewModel.isSelected(asset.localIdentifier)
            cell.configure(image: image, isSelected: isSelected)
        }
        return cell
    }
}

extension PhotoPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.isSelectionMode{
            let asset = viewModel.asset(at: indexPath)
            viewModel.toggleSelection(for: asset.localIdentifier)
            UIView.performWithoutAnimation {
                collectionView.reloadItems(at: [indexPath])
            }
        }
    }
}
