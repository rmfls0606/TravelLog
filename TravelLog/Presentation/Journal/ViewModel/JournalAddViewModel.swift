//
//  JournalAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RxCocoa
import LinkPresentation
import UIKit
import RealmSwift

final class JournalAddViewModel: BaseViewModel {
    
    // MARK: - Input / Output
    struct Input {
        let saveTapped: Observable<[JournalBlockData]>
    }
    
    struct Output {
        let saveCompleted: Signal<Void>
    }
    
    // MARK: - Block Data 구조
    struct JournalBlockData {
        let type: JournalBlockType
        let text: String?
        let linkURL: String?
        
        // 메타데이터 확장 필드
        var linkTitle: String? = nil
        var linkDescription: String? = nil
        var linkImage: UIImage? = nil
        
        //사진 확장 필드
        var photoDescription: String? = nil
        var photoImages: [UIImage]? = nil
    }
    
    // MARK: - Properties
    private let tripId: ObjectId
    private let selectedDate: Date
    private let useCase: JournalUseCaseType
    private let disposeBag = DisposeBag()
    
    init(tripId: ObjectId, date: Date, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.selectedDate = date
        self.useCase = useCase
    }
    
    // MARK: - Transform
    func transform(input: Input) -> Output {
        let saveCompleted = input.saveTapped
            .flatMapLatest { [weak self] blocks -> Observable<Void> in
                guard let self else { return .empty() }
                
                let validBlocks = blocks.filter {
                    switch $0.type {
                    case .text:
                        return !($0.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    case .link:
                        return !($0.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    case .photo:
                        return !($0.photoImages?.isEmpty ?? true) ||
                               !($0.photoDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    default:
                        return false
                    }
                }
                guard !validBlocks.isEmpty else { return .empty() }
                
                let metadataFetches: [Single<JournalBlockData>] = validBlocks.map { block in
                    if block.type == .link, let urlString = block.linkURL {
                        return self.fetchLinkMetadata(for: urlString)
                            .map { title, desc, image in
                                var newBlock = block
                                newBlock.linkTitle = title
                                newBlock.linkDescription = desc
                                newBlock.linkImage = image
                                return newBlock
                            }
                            .catchAndReturn(block)
                    } else {
                        return .just(block)
                    }
                }
                
                return Single.zip(metadataFetches)
                    .flatMapCompletable { [weak self] results in
                        guard let self else { return .empty() }
                        let operations = results.map {
                            self.useCase.addJournal(
                                tripId: self.tripId,
                                type: $0.type,
                                text: $0.text,
                                linkURL: $0.linkURL,
                                linkTitle: $0.linkTitle,
                                linkDescription: $0.linkDescription,
                                linkImage: $0.linkImage,
                                photoDescription: $0.photoDescription,
                                photoImages: $0.photoImages,
                                date: self.selectedDate
                            )
                        }
                        return Completable.zip(operations)
                    }
                    .andThen(Observable.just(()))
            }
            .asSignal(onErrorSignalWith: .empty())
        
        return Output(saveCompleted: saveCompleted)
    }
    
    // MARK: - LPMetadataProvider로 링크 미리보기 메타데이터 불러오기
    private func fetchLinkMetadata(for urlString: String)
    -> Single<(String?, String?, UIImage?)> {
        return Single.create { single in
            // URL 정규화
            guard let normalized = URLNormalizer.normalized(urlString) else {
                single(.success((nil, nil, nil)))
                return Disposables.create()
            }

            let url = normalized.url   // 실제 URL 추출

            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error = error {
                    print("LPMetadataProvider Error:", error.localizedDescription)
                    single(.success((nil, nil, nil)))
                    return
                }

                guard let metadata = metadata else {
                    single(.success((nil, nil, nil)))
                    return
                }

                // 기본 정보
                let title = metadata.title ?? url.host ?? "링크 미리보기"
                let desc = metadata.value(forKey: "summary") as? String ?? url.absoluteString

                // 이미지 로드
                if let imageProvider = metadata.imageProvider {
                    imageProvider.loadObject(ofClass: UIImage.self) { imageObj, _ in
                        let image = imageObj as? UIImage
                        single(.success((title, desc, image)))
                    }
                } else {
                    single(.success((title, desc, nil)))
                }
            }

            return Disposables.create()
        }
    }
}
