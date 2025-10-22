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

    struct JournalBlockData {
        let type: JournalBlockType
        let text: String?
        let linkURL: String?
    }

    struct Input {
        let saveTapped: Observable<[JournalBlockData]>
    }

    struct Output {
        let saveCompleted: Signal<Void>
    }

    private let useCase: JournalUseCaseType
    private let tripId: ObjectId
    private let selectedDate: Date
    private let disposeBag = DisposeBag()

    init(tripId: ObjectId, date: Date, useCase: JournalUseCaseType = JournalUseCase()) {
        self.tripId = tripId
        self.selectedDate = date
        self.useCase = useCase
    }

    func transform(input: Input) -> Output {
        let saveCompleted = input.saveTapped
            .flatMapLatest { [weak self] blockDataArray -> Observable<Void> in
                guard let self else { return .empty() }

                let validBlockData = blockDataArray.filter { ($0.text != nil && !$0.text!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || ($0.linkURL != nil && !$0.linkURL!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                guard !validBlockData.isEmpty else { return .empty() }

                let ops = validBlockData.map {
                    self.useCase.addJournal(tripId: self.tripId, type: $0.type, text: $0.text, linkURL: $0.linkURL, date: self.selectedDate)
                }

                return Completable.zip(ops).andThen(Observable.just(()))
            }
            .asSignal(onErrorSignalWith: .empty())

        return Output(saveCompleted: saveCompleted)
    }
}
