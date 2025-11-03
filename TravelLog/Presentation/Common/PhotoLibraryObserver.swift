//
//  PhotoLibraryObserver.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import Photos

final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {

    private var fetchResult: PHFetchResult<PHAsset>?
    var changeHandler: ((PHFetchResult<PHAsset>) -> Void)?

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func fetchAssets(){
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        self.fetchResult = result
        changeHandler?(result)
    }

    // 앨범 변경 감지
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult,
              let changes = changeInstance.changeDetails(for: fetchResult) else { return }
        let newResult = changes.fetchResultAfterChanges
        self.fetchResult = newResult
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?(newResult)
        }
    }
}
