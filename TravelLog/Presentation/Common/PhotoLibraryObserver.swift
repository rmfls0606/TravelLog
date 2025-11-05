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
            
            if changes.hasIncrementalChanges {
                // 1. 삽입된 항목이 있는지 확인
                let hasInsertions = (changes.insertedIndexes?.count ?? 0) > 0
                // 2. 삭제된 항목이 있는지 확인
                let hasRemovals = (changes.removedIndexes?.count ?? 0) > 0
                
                // 3.만약 삽입/삭제가 '전혀' 없다면 (즉, '편집'만 되었다면)
                if !hasInsertions && !hasRemovals {
                    
                    // 4. ViewModel에 'reloadData' 신호를 보내지 말고,
                    self.fetchResult = changes.fetchResultAfterChanges
                    return
                }
            }
        
            let newResult = changes.fetchResultAfterChanges
            self.fetchResult = newResult
            
            DispatchQueue.main.async { [weak self] in
                self?.changeHandler?(newResult)
            }
        }
}
