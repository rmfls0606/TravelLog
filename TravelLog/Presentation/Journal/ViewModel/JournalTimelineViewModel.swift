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
    }

    struct Output {
        let journals: Driver<[JournalTable]>
        let navigateToAdd: Signal<ObjectId>
    }

    private let useCase: JournalUseCaseType
    private let tripId: ObjectId
    private let disposeBag = DisposeBag()

    init(tripId: ObjectId, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.useCase = useCase
    }

    func transform(input: Input) -> Output {
        // ✅ fetch 시 Observable을 Driver로 변환
        let journals = input.viewWillAppear
            .flatMapLatest { [weak self] _ -> Observable<[JournalTable]> in
                guard let self = self else { return .just([]) }
                
                return self.useCase.fetchJournals(tripId: self.tripId)
            }
            .asDriver(onErrorJustReturn: []) // ✅ 여기서 변환 완료

        let navigateToAdd = input.addTapped
            .map { [weak self] in self?.tripId }
            .compactMap { $0 }
            .asSignal(onErrorSignalWith: .empty())

        return Output(
            journals: journals,
            navigateToAdd: navigateToAdd
        )
    }
}
