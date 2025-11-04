//
//  PhotoPickerViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 11/2/25.
//

import Foundation
import PhotosUI
import UIKit

//사진 접근 권한, 페이징 로딩, 선택 상대 관리, 이미지 캐싱 등을 담당.
final class PhotoPickerViewModel{
    
    private let observer = PhotoLibraryObserver() //PHPhotoLibrary 변경 감시자
    private var fetchResult: PHFetchResult<PHAsset>? //전체 PHAsset 목록
    private(set) var loadedAssets: [PHAsset] = [] //현재 로드된 페이지의 Asset
    private var selectedAssets: Set<String> = [] //선택된 Asset Identifier 집합
    private var pageSize = 300 //한 번에 불러올 개수
    private var isFetching = false
    private let queue = DispatchQueue(label: "photo.loader.queue", qos: .userInitiated)
    
    //선택 모드 상태
    private(set) var isSelectionMode: Bool = false{
        didSet{
            onSelectionModeChanged?(isSelectionMode)
        }
    }
    
    //전체 선택 상태
    private(set) var isAllSelected: Bool = false{
        didSet{
            onSelectAllToggled?(isAllSelected)
        }
    }
    
    //제한 접근 여부
    private(set) var isLimitedAccess = false
    
    // 뷰컨에 보낼 콜백
    var onAssetsChanged: (([PHAsset]) -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onSelectionModeChanged: ((Bool) -> Void)?
    var onSelectAllToggled: ((Bool) -> Void)?
    var onSelectionUpdated: (([String: Bool]) -> Void)?
    var onLimitedAccessDetected: (() -> Void)?
    
    private let imageManager = {
        let manager = PHCachingImageManager()
        manager.allowsCachingHighQualityImages = true
        return manager
    }()
    private let imageOptions: PHImageRequestOptions = {
        let opt = PHImageRequestOptions()
        opt.deliveryMode = .highQualityFormat //고화질 조정
        opt.resizeMode = .exact
        opt.isNetworkAccessAllowed = true
        opt.isSynchronous = false
        return opt
    }()
    
    private(set) var startIndex: Int?
    private(set) var lastIndex: Int?
    private(set) var selectedRange: ClosedRange<Int>?
    private(set) var originalSelectionState: [String: Bool] = [:]
    private(set) var isRemovingMode = false
    
    init() {
        //포토라이브러리 변경 감시 - 사진 추가/삭제 시 자동 갱신
        observer.changeHandler = { [weak self] result in
            self?.fetchResult = result
            self?.loadedAssets.removeAll()
            self?.loadMoreAssetsIfNeeded()
        }
    }
    
    // MARK: - 권한 확인 및 초기 Fetch
    func checkPermission() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            handleAuthStatus(newStatus)
        default:
            handleAuthStatus(status)
        }
    }
    
    //권한 상태에 따른 처리
    private func handleAuthStatus(_ status: PHAuthorizationStatus){
        switch status{
        case .authorized:
            isLimitedAccess = false
            observer.fetchAssets()
        case .limited:
            isLimitedAccess = true
            observer.fetchAssets()
            onLimitedAccessDetected?()
        default:
            onPermissionDenied?()
        }
    }
    
    //MARK: - 페이지네이션
    func loadMoreAssetsIfNeeded() {
        guard !isFetching, let result = fetchResult else { return }
        guard loadedAssets.count < result.count else { return }
        
        isFetching = true
        queue.async { [weak self] in
            guard let self = self else { return }
            let nextEnd = min(self.loadedAssets.count + self.pageSize, result.count)
            let range = IndexSet(self.loadedAssets.count..<nextEnd)
            let newAssets = result.objects(at: range)
            DispatchQueue.main.async {
                self.loadedAssets.append(contentsOf: newAssets)
                self.onAssetsChanged?(self.loadedAssets)
                self.isFetching = false
            }
        }
    }
    
    func prefetchImages(for indexes: [Int], targetSize: CGSize) {
        guard let result = fetchResult else { return }
        let assets = indexes.compactMap { $0 < result.count ? result.object(at: $0) : nil }
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: imageOptions
        )
    }
    
    func cancelPrefetch(for indexes: [Int], targetSize: CGSize) {
        guard let result = fetchResult else { return }
        let assets = indexes.compactMap { $0 < result.count ? result.object(at: $0) : nil }
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: imageOptions
        )
    }
    
    // MARK: - 썸네일 요청
    //AsyncStream으로 안전하게 이미지 스트리밍(저화질 -> 고화질)
    func requestThumbnail(for asset: PHAsset, targetSize: CGSize) -> AsyncStream<UIImage?> {
        AsyncStream { continuation in
            final class State { var finished = false }
            let state = State()
            
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: imageOptions
            ) { image, info in
                guard let image = image, !state.finished else { return }
                
                continuation.yield(image)
                
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    state.finished = true
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { [weak self] _ in
                self?.imageManager.cancelImageRequest(requestID)
                state.finished = true
            }
        }
    }
    
    //선택 모드 전환
    func toggleSelectionMode(){
        isSelectionMode.toggle()
        if !isSelectionMode{
            clearSelections()
            isAllSelected = false
        }
    }
    
    func clearSelections(){
        selectedAssets.removeAll()
        onSelectionUpdated?([:])
    }
    
    func toggleSelection(for identifier : String){
        if selectedAssets.contains(identifier){
            selectedAssets.remove(identifier)
        }else{
            selectedAssets.insert(identifier)
        }
        isAllSelected = (selectedAssets.count == loadedAssets.count)
        onSelectionUpdated?([identifier: selectedAssets.contains(identifier)])
    }
    
    func toggleSelectAll(){
        if isAllSelected{
            selectedAssets.removeAll()
            isAllSelected = false
        }else{
            selectedAssets = Set(loadedAssets.map{ $0.localIdentifier })
            isAllSelected = true
        }
        let map = loadedAssets.reduce(into: [String: Bool]()){
            $0[$1.localIdentifier] = self.isAllSelected
        }
        onSelectionUpdated?(map)
    }
    
    func isSelected(_ identifier: String) -> Bool{
        selectedAssets.contains(identifier)
    }
    
    func numberOfItems() -> Int {
        return loadedAssets.count
    }
    
    func asset(at indexPath: IndexPath) -> PHAsset {
        return loadedAssets[indexPath.item]
    }
    
    //MARK: - 드래그 선택 관리
    func beginRangeSelection(at index: Int){
        guard index < loadedAssets.count else { return }
        startIndex = index
        selectedRange = index...index
        lastIndex = index
        originalSelectionState.removeAll()
        
        let asset = loadedAssets[index]
        let id = asset.localIdentifier
        let wasSelected = isSelected(id)
        isRemovingMode = wasSelected
        
        // 즉시 반전하지 않음 — 단순히 상태 기록만
        originalSelectionState[id] = wasSelected
    }
    
    func updateRangeSelection(to index: Int){
        guard let start = startIndex else { return }
        
        let minItem = min(start, index)
        let maxItem = max(start, index)
        let newRange = minItem...maxItem
        var changed: [String: Bool] = [:]
        
        // 새 구간 내 셀들 업데이트
        for i in newRange {
            let asset = loadedAssets[i]
            let id = asset.localIdentifier
            
            if originalSelectionState[id] == nil {
                originalSelectionState[id] = isSelected(id)
            }
            
            if isRemovingMode {
                if isSelected(id) {
                    selectedAssets.remove(id)
                    changed[id] = false
                }
            } else {
                if !isSelected(id) {
                    selectedAssets.insert(id)
                    changed[id] = true
                }
            }
        }
        
        // 이전 구간에 있었지만 새 구간에 없는 셀 복원
        if let oldRange = selectedRange {
            for i in oldRange where !newRange.contains(i) {
                let asset = loadedAssets[i]
                let id = asset.localIdentifier
                if let original = originalSelectionState[id],
                   isSelected(id) != original {
                    if original {
                        selectedAssets.insert(id)
                    } else {
                        selectedAssets.remove(id)
                    }
                    changed[id] = original
                }
            }
        }
        
        selectedRange = newRange
        
        // 즉시 반영
        if !changed.isEmpty {
            onSelectionUpdated?(changed)
        }
    }
    
    func endRangeSelection() {
        // 드래그 종료 시 추가 조정 없음 (상태 그대로 확정)
        startIndex = nil
        lastIndex = nil
        selectedRange = nil
        originalSelectionState.removeAll()
    }
}
