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
        let saveTapped: Observable<[String]> // ✅ 여러 텍스트 블록의 내용을 한 번에 받음
    }
    
    struct Output {
        let saveCompleted: Signal<Void>
    }
    
    private let useCase: JournalUseCaseType
    private let tripId: ObjectId
    private let disposeBag = DisposeBag()
    
    init(tripId: ObjectId, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.useCase = useCase
    }
    
    func transform(input: Input) -> Output {
        // ✅ 저장 버튼 누르면 전체 텍스트 배열 처리
        let saveCompleted = input.saveTapped
            .flatMapLatest { [weak self] texts -> Observable<Void> in
                guard let self = self else { return .empty() }
                let nonEmptyTexts = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard !nonEmptyTexts.isEmpty else { return .empty() }

                // 각 텍스트마다 addJournal 호출
                let ops = nonEmptyTexts.map {
                    self.useCase.addJournal(tripId: self.tripId, text: $0)
                }
                return Completable.zip(ops)
                    .andThen(Observable.just(()))
            }
            .asSignal(onErrorSignalWith: .empty())
        
        return Output(saveCompleted: saveCompleted)
    }
}
