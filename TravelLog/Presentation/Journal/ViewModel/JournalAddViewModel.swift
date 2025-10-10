//
//  JournalAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RxCocoa
import RealmSwift

final class JournalAddViewModel: BaseViewModel {
    
    struct Input {
        let textChanged: Observable<String>
        let saveTapped: Observable<Void>
    }
    
    struct Output {
        let isSaveEnabled: Driver<Bool>
        let saveCompleted: Signal<Void>
    }
    
    private let useCase: JournalUseCaseType
    private let tripId: ObjectId
    private let disposeBag = DisposeBag()
    
    // ✅ 텍스트 블록 관리
    private let textBlocks = BehaviorRelay<[String]>(value: [])
    
    init(tripId: ObjectId, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.useCase = useCase
    }
    
    func transform(input: Input) -> Output {
        // ✅ 텍스트 입력 유무로 버튼 활성화
        let isSaveEnabled = input.textChanged
            .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .asDriver(onErrorJustReturn: false)
        
        // ✅ 저장 버튼 탭 시
        let saveCompleted = input.saveTapped
            .withLatestFrom(textBlocks.asObservable())
            .flatMapLatest { [weak self] texts -> Observable<Void> in
                guard let self = self else { return .empty() }
                guard !texts.isEmpty else { return .empty() }
                
                let saveOperations = texts.map { self.useCase.addJournal(tripId: self.tripId, text: $0) }
                return Completable.zip(saveOperations)
                    .andThen(Observable.just(())) // 모든 저장 완료 시 이벤트 방출
            }
            .asSignal(onErrorSignalWith: .empty())
        
        return Output(isSaveEnabled: isSaveEnabled, saveCompleted: saveCompleted)
    }
    
    // ✅ 새로운 블록 추가
    func addTextBlock(_ text: String) {
        var blocks = textBlocks.value
        blocks.append(text)
        textBlocks.accept(blocks)
    }
    
    // ✅ “저장하기” 수동 호출 (VC에서 직접 호출 시)
    func saveAllBlocks() -> Completable {
        let texts = textBlocks.value
        guard !texts.isEmpty else { return .empty() }
        let operations = texts.map { useCase.addJournal(tripId: tripId, text: $0) }
        return Completable.zip(operations)
    }
    
    func updateLatestTextBlock(_ text: String) {
        var blocks = textBlocks.value
        if blocks.isEmpty {
            blocks.append(text)
        } else {
            // 마지막 블록만 업데이트 (새로운 블록 추가 X)
            blocks[blocks.count - 1] = text
        }
        textBlocks.accept(blocks)
    }
}
