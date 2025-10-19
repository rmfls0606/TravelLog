//
//  JournalTimelineViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import Foundation
import RxSwift
import RxCocoa
import RealmSwift

final class JournalTimelineViewModel: BaseViewModel {
    struct Input {
        let viewWillAppear: Observable<Void>
        let addTapped: Observable<Void>
        let deleteTapped: Observable<(ObjectId, ObjectId)>
    }
    
    struct Output {
        let journals: Driver<[JournalTable]>
        let navigateToAdd: Observable<ObjectId>
        let deleteCompleted: Observable<Void>
    }
    
    private let useCase: JournalUseCaseType
    private let tripId: ObjectId
    private let disposeBag = DisposeBag()
    
    init(tripId: ObjectId, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.useCase = useCase
    }
    
    func transform(input: Input) -> Output {
        // 1. Journal 리스트
        let journals = input.viewWillAppear
            .flatMapLatest { [weak self] _ -> Observable<[JournalTable]> in
                guard let self = self else { return .just([]) }
                return self.useCase.fetchJournals(tripId: self.tripId)
            }
            .asDriver(onErrorJustReturn: []) // 여기서 Driver로 변환
        
        // 2. Add 이동 이벤트
        let navigateToAdd = input.addTapped
            .compactMap { [weak self] _ in self?.tripId }
        
        // 3. 삭제 완료 이벤트 (핵심)
        let deleteCompleted = input.deleteTapped
            .flatMapLatest { [weak self] (journalId, blockId) -> Observable<Void> in
                guard let self else { return .empty() }
                return self.useCase.deleteJournalBlock(journalId: journalId, blockId: blockId)
                    .andThen(Observable.just(())) // Completable → Observable로 변환
            }
        
        return Output(
            journals: journals,
            navigateToAdd: navigateToAdd,
            deleteCompleted: deleteCompleted
        )
    }
}
