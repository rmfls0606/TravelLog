//
//  TravelRepository.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import Foundation
import RealmSwift
import RxSwift

protocol TravelRepositoryType {
    func createTravel(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable
}

final class TravelRepository: TravelRepositoryType {
    
    private let realm: Realm
    
    init() {
        do {
            realm = try Realm()
            print(realm.configuration.fileURL)
        } catch {
            fatalError("Realm 초기화 실패: \(error)")
        }
    }
    
    func createTravel(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self else {
                completable(.error(NSError(domain: "Repository", code: -1)))
                return Disposables.create()
            }
            do {
                try self.realm.write {
                    // 먼저 CityTable 객체 등록 (이미 있으면 업데이트)
                    self.realm.add([departure, destination], update: .modified)
                    
                    // TravelTable 객체 생성
                    let travel = TravelTable(
                        departure: departure,
                        destination: destination,
                        startDate: startDate,
                        endDate: endDate,
                        transport: transport,
                        createdAt: Date(),
                        updateAt: Date()
                    )
                    self.realm.add(travel)
                }
                print("Realm 저장 성공")
                completable(.completed)
            } catch {
                print("Realm 저장 실패:", error.localizedDescription)
                completable(.error(error))
            }
            
            return Disposables.create()
        }
    }
}
