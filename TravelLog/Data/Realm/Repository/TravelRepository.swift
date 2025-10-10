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
    
    func fetchTrips() -> Observable<[TravelTable]>
    func deleteTravel(_ trip: TravelTable)
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
    
    // MARK: - 여행 생성
    func createTravel(
        departure: CityTable,
        destination: CityTable,
        startDate: Date,
        endDate: Date,
        transport: Transport
    ) -> Completable {
        return Completable.create { [weak self] completable in
            guard let self = self else {
                completable(.error(NSError(domain: "TravelRepository", code: -1)))
                return Disposables.create()
            }
            
            do {
                try self.realm.write {
                    self.realm.add([departure, destination], update: .modified)
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
                completable(.completed)
            } catch {
                completable(.error(error))
            }
            
            return Disposables.create()
        }
    }
    
    // MARK: - 여행 목록 (Realm 변경 실시간 감지)
    func fetchTrips() -> Observable<[TravelTable]> {
        return Observable.create { [weak self] observer in
            guard let self = self else {
                observer.onCompleted()
                return Disposables.create()
            }
            
            let results = self.realm.objects(TravelTable.self)
                .sorted(byKeyPath: "startDate", ascending: true)
            
            // 최초 emit
            observer.onNext(Array(results))
            
            // Realm 변경 감지
            let token = results.observe { changes in
                switch changes {
                case .initial(let collection),
                     .update(let collection, _, _, _):
                    observer.onNext(Array(collection))
                case .error(let error):
                    observer.onError(error)
                }
            }
            
            // invalidate() 없이 token 참조만 끊기
            return Disposables.create {
                _ = token // token 유지 (Realm 내부에서 자동 해제)
            }
        }
    }
    
    // MARK: - 여행 삭제
    func deleteTravel(_ trip: TravelTable) {
        do {
            try realm.write {
                // 1️⃣ tripId로 연결된 JournalTable 모두 찾기
                let journals = realm.objects(JournalTable.self)
                    .filter("tripId == %@", trip.id)
                
                // 2️⃣ 각 Journal의 blocks 삭제
                for journal in journals {
                    realm.delete(journal.blocks)
                }
                
                // 3️⃣ JournalTable 삭제
                realm.delete(journals)
                
                // 4️⃣ TravelTable 삭제
                realm.delete(trip)
            }
            print("✅ 여행 및 관련 일지/블록 모두 삭제 완료")
        } catch {
            print("❌ 삭제 실패:", error.localizedDescription)
        }
    }
}
