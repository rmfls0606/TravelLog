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
    
    private var dataSource: UICollectionViewDiffableDataSource<Int, PHAsset>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureLayout()
        configureView()
        configureDataSource()
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
    }
    
    private func configureBind() {
        viewModel.onAssetsChanged = { [weak self] assets in
            self?.applySnapshot(assets)
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
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, asset in
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoThumbnailCell.identifier, for: indexPath) as? PhotoThumbnailCell else {
                      return UICollectionViewCell()
                  }
            
            Task {
                let itemSize = (collectionView.bounds.width - 4) / 3
                let size = CGSize(width: itemSize * UIScreen.main.scale,
                                  height: itemSize * UIScreen.main.scale)
                if let image = await self.viewModel.requestThumbnail(for: asset, targetSize: size) {
                    cell.configure(image: image)
                }
            }
            return cell
        }
    }
    
    private func applySnapshot(_ assets: [PHAsset]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, PHAsset>()
        snapshot.appendSections([0])
        snapshot.appendItems(assets)
        dataSource.apply(snapshot)
    }
}
