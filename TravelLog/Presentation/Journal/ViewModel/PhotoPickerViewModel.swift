//
//  PhotoPickerViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import Foundation
import PhotosUI
import UIKit

final class PhotoPickerViewModel{
    
    private let observer = PhotoLibraryObserver()
    private var assets: [PHAsset] = []
    private var selectedAssets: Set<String> = []
    private(set) var isSelectionMode: Bool = false{
        didSet{
            onSelectionModeChanged?(isSelectionMode)
        }
    }
    
    // 뷰컨에 보낼 콜백
    var onAssetsChanged: (([PHAsset]) -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onSelectionModeChanged: ((Bool) -> Void)?
    
    init() {
        // 옵저버에서 변화 감지
        observer.changeHandler = { [weak self] updated in
            self?.assets = updated
            self?.onAssetsChanged?(updated)
        }
    }
    
    // MARK: - 권한 확인
    func checkPermission() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus == .authorized || newStatus == .limited {
                observer.fetchAssets()
            } else {
                self.onPermissionDenied?()
            }
        case .authorized, .limited:
            observer.fetchAssets()
        default:
            self.onPermissionDenied?()
        }
    }
    
    // MARK: - 썸네일
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let manager = PHCachingImageManager.default()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            options.deliveryMode = .opportunistic
            
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    //선택 모드 전환
    func toggleSelectionMode(){
        isSelectionMode.toggle()
    }
    
    func clearSelections(){
        selectedAssets.removeAll()
    }
    
    func toggleSelection(for identifier : String){
        if selectedAssets.contains(identifier){
            selectedAssets.remove(identifier)
        }else{
            selectedAssets.insert(identifier)
        }
    }
    
    func isSelected(_ identifier: String) -> Bool{
        selectedAssets.contains(identifier)
    }
    
    func numberOfItems() -> Int {
        return assets.count
    }
    
    func asset(at indexPath: IndexPath) -> PHAsset {
        return assets[indexPath.item]
    }
}
