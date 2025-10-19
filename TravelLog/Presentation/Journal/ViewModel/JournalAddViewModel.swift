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
        let saveTapped: Observable<[String]>
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
        let saveCompleted = input.saveTapped
            .flatMapLatest { [weak self] texts -> Observable<Void> in
                guard let self else { return .empty() }
                let validTexts = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard !validTexts.isEmpty else { return .empty() }

                let ops = validTexts.map {
                    self.useCase.addJournal(tripId: self.tripId, text: $0)
                }

                return Completable.zip(ops).andThen(Observable.just(()))
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(saveCompleted: saveCompleted)
    }
}
