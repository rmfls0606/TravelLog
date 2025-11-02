//
//  PhotoLibraryObserver.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import Photos

final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {

    private var fetchResult: PHFetchResult<PHAsset>?
    var changeHandler: (([PHAsset]) -> Void)?

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
        fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        updateAssets()
    }
    
    func updateAssets(){
        guard let fetchResult = fetchResult else { return }
        //앱에서 사용할 수 있는 형태 변환
        let assets = fetchResult.objects(at: IndexSet(0..<fetchResult.count))
        self.changeHandler?(assets)
    }

    // 앨범 변경 감지
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let fetchResult,
              let changes = changeInstance.changeDetails(for: fetchResult) else { return }

        DispatchQueue.main.async {
            self.fetchResult = changes.fetchResultAfterChanges
            self.updateAssets()
        }
    }
}
