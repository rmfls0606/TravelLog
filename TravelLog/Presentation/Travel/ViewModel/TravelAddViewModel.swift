//
//  TravelAddViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import RxSwift
import RxCocoa
import Foundation

final class TravelAddViewModel: BaseViewModel {

    private(set) var selectedDateRelay = BehaviorRelay<(start: Date?, end: Date?)>(value: (nil, nil))
    private(set) var selectedTransportRelay = BehaviorRelay<Transport>(value: .airplane)

    private let departureRelay = PublishRelay<CityTable>()
    private let destinationRelay = PublishRelay<CityTable>()

    private let createTripUseCase: CreateTripUseCase
    private let increaseCityPopularityUseCase: IncreaseCityPopularityUseCase
    private let scanTicketUseCase: ScanTicketUseCase
    private let resolveScannedCityUseCase: ResolveScannedCityUseCase

    private let disposeBag = DisposeBag()

    init(
        createTripUseCase: CreateTripUseCase = CreateTripUseCaseImpl(
            repository: TripRepositoryImpl()
        ),
        increaseCityPopularityUseCase: IncreaseCityPopularityUseCase = IncreaseCityPopularityUseCaseImpl(
            repository: CityRepositoryImpl(
                local: FirebaseCityDataSource(),
                remote: FunctionsCityRemoteDataSource(region: "us-central1")
            )
        ),
        scanTicketUseCase: ScanTicketUseCase = ScanTicketUseCaseImpl(
            repository: TicketScanRepositoryImpl(
                remote: FunctionsTicketScanRemoteDataSource(region: "us-central1")
            )
        ),
        resolveScannedCityUseCase: ResolveScannedCityUseCase = ResolveScannedCityUseCaseImpl(
            fetchCitiesUseCase: FetchCitiesUseCaseImpl(
                repository: CityRepositoryImpl(
                    local: FirebaseCityDataSource(),
                    remote: FunctionsCityRemoteDataSource(region: "us-central1")
                )
            )
        )
    ) {
        self.createTripUseCase = createTripUseCase
        self.increaseCityPopularityUseCase = increaseCityPopularityUseCase
        self.scanTicketUseCase = scanTicketUseCase
        self.resolveScannedCityUseCase = resolveScannedCityUseCase
    }

    struct Input{
        let transportSelected: Observable<Transport>
        let dateSelected: Observable<(Date?, Date?)>
        let calendarTapped: Observable<Void>
        let createButtonTapped: ControlEvent<Void>
        let ticketImageSelected: Observable<(imageData: Data, mimeType: String)>
    }

    struct Output{
        private(set) var selectedTransport: Driver<Transport>
        private(set) var selectedDateRange: Driver<(start: Date?, end: Date?)>
        private(set) var showCalendar: Signal<Void>
        private(set) var saveCompleted: Signal<Void>
        private(set) var toastMessage: Signal<String>
        private(set) var isScanningTicket: Driver<Bool>
        private(set) var ticketScanApplied: Signal<TicketScanApplySummary>
        private(set) var ticketScanFailed: Signal<String>
    }

    //MARK: - 티켓 스캔 파이프라인이 성공/실패 중 어느 쪽이었는지 내부적으로 구분하기 위한 타입
    private enum TicketScanOutcome {
        case success(result: TicketScanResult, departure: City?, destination: City?)
        case failure(String)
    }

    func transform(input: Input) -> Output {
        input.transportSelected
            .bind(to: selectedTransportRelay)
            .disposed(by: disposeBag)

        input.dateSelected
            .map{(start: $0.0, end: $0.1)}
            .bind(to: selectedDateRelay)
            .disposed(by: disposeBag)

        let showCalendar = input.calendarTapped
            .asSignal(onErrorJustReturn: ())

        let isScanningTicketRelay = BehaviorRelay<Bool>(value: false)

        let ticketScanOutcome: Observable<TicketScanOutcome> = input.ticketImageSelected
            .do(onNext: { _ in isScanningTicketRelay.accept(true) })
            .flatMapLatest { [weak self] imageData, mimeType -> Observable<TicketScanOutcome> in
                guard let self else { return .empty() }
                return self.scanTicket(imageData: imageData, mimeType: mimeType)
            }
            .do(onNext: { _ in isScanningTicketRelay.accept(false) })
            .share()

        ticketScanOutcome
            .bind(with: self) { owner, outcome in
                guard case let .success(result, departureCity, destinationCity) = outcome else { return }
                owner.applyTicketScan(result: result, departureCity: departureCity, destinationCity: destinationCity)
            }
            .disposed(by: disposeBag)

        let ticketScanApplied = ticketScanOutcome
            .compactMap { outcome -> TicketScanApplySummary? in
                guard case let .success(result, departureCity, destinationCity) = outcome else { return nil }
                return TicketScanApplySummary(
                    departureCityName: departureCity?.name,
                    destinationCityName: destinationCity?.name,
                    confidence: result.confidence,
                    notes: result.notes
                )
            }
            .asSignal(onErrorSignalWith: .empty())

        let ticketScanFailed = ticketScanOutcome
            .compactMap { outcome -> String? in
                if case let .failure(message) = outcome { return message }
                return nil
            }
            .asSignal(onErrorJustReturn: "티켓 이미지를 분석하지 못했어요. 잠시 후 다시 시도해주세요.")
        
        let combinedInputs: Observable<(CityTable, CityTable, Date, Date, Transport)> = Observable.combineLatest(
            departureRelay.compactMap { $0 },
            destinationRelay.compactMap { $0 },
            selectedDateRelay.compactMap { $0.start },
            selectedDateRelay.compactMap { $0.end },
            selectedTransportRelay
        )
        
        let createTrigger = input.createButtonTapped
            .withLatestFrom(combinedInputs)
        
        let saveResult: Observable<Result<Void, RealmError>> = createTrigger
            .flatMapLatest { [weak self] (dep, dest, start, end, transport) -> Observable<Result<Void, RealmError>> in
                guard let self else { return .empty() }
                
                // Realm 저장 로직 실행
                let createProcess: Observable<Result<Void, RealmError>> =
                self.createTripUseCase.execute(
                    departure: dep,
                    destination: dest,
                    startDate: start,
                    endDate: end,
                    transport: transport
                )
                .andThen(
                    self.increasePopularityIfNeeded(for: dest)
                        .catch { error in
                            print("City popularity increase failed:", error.localizedDescription)
                            return .empty()
                        }
                )
                .andThen(Observable.just(.success(())))
                .catch { error in
                    return Observable.just(.failure(.saveFailure))
                }
                
                return createProcess
            }
            .share()
        
        let saveCompleted = saveResult
            .compactMap {
                if case .success = $0 { return () }
                else{ return nil }
            }
            .asSignal(onErrorSignalWith: .empty())
        
        let toastMessage = saveResult
            .compactMap { result -> String? in
                if case let .failure(error) = result {
                    return error.errorDescription
                }
                return nil
            }
            .asSignal(onErrorJustReturn: "데이터 저장 중 문제가 발생했어요.\n잠시 후 다시 시도해주세요.")
        
        return Output(
            selectedTransport: selectedTransportRelay.asDriver(),
            selectedDateRange: selectedDateRelay.asDriver(),
            showCalendar: showCalendar,
            saveCompleted: saveCompleted,
            toastMessage: toastMessage,
            isScanningTicket: isScanningTicketRelay.asDriver(),
            ticketScanApplied: ticketScanApplied,
            ticketScanFailed: ticketScanFailed
        )
    }
    
    func updateDateRange(range: (start: Date?, end: Date?)){
        selectedDateRelay.accept(range)
    }
    
    func updateDeparture(_ city: CityTable) {
        departureRelay.accept(city)
    }
    
    func updateDestination(_ city: CityTable) {
        destinationRelay.accept(city)
    }

    //MARK: - 이미지를 서버로 보내 분석하고, 인식된 도시 텍스트를 실제 City로 해석까지 마친 뒤 결과를 돌려준다
    private func scanTicket(imageData: Data, mimeType: String) -> Observable<TicketScanOutcome> {
        scanTicketUseCase.execute(imageData: imageData, mimeType: mimeType)
            .flatMap { [weak self] result -> Single<TicketScanOutcome> in
                guard let self else {
                    return .just(.failure("티켓 이미지를 분석하지 못했어요. 잠시 후 다시 시도해주세요."))
                }

                guard result.isTicket else {
                    let message = result.notes ?? "티켓 사진으로 인식하지 못했어요. 다시 촬영하거나 직접 입력해주세요."
                    return .just(.failure(message))
                }

                return Single.zip(
                    self.resolveScannedCityUseCase.execute(
                        cityName: result.departureCity,
                        countryHint: result.departureCountry
                    ),
                    self.resolveScannedCityUseCase.execute(
                        cityName: result.destinationCity,
                        countryHint: result.destinationCountry
                    )
                )
                .map { departureCity, destinationCity in
                    .success(result: result, departure: departureCity, destination: destinationCity)
                }
            }
            .asObservable()
            .catch { error in
                let scanError = (error as? TicketScanError) ?? .unknown
                return .just(.failure(TicketScanErrorPresenter.message(for: scanError)))
            }
    }

    //MARK: - 스캔 결과를 교통수단/날짜/출발지/도착지 상태에 반영
    private func applyTicketScan(result: TicketScanResult, departureCity: City?, destinationCity: City?) {
        if let transport = result.transport {
            selectedTransportRelay.accept(transport)
        }

        // 티켓 한 장에는 보통 그 편(便)의 출발일만 나와 있고 왕복/전체 여행 기간은 알 수 없다.
        // endDate를 모르면 start로 임의 대체하지 않고 비워 둬서, 사용자가 직접 도착일을 채우게 한다
        // (DateRangeCardView는 start/end가 모두 있어야만 값을 표시하고, 그 전까지는 "날짜를 선택하세요" 상태를 유지한다).
        if let start = result.startDate {
            selectedDateRelay.accept((start: start, end: result.endDate))
        }

        if let departureCity {
            departureRelay.accept(CityTable(from: departureCity))
        }

        if let destinationCity {
            destinationRelay.accept(CityTable(from: destinationCity))
        }
    }

    private func increasePopularityIfNeeded(for city: CityTable) -> Completable {
        guard let cityDocId = city.cityDocId, !cityDocId.isEmpty else {
            print("City popularity increment skipped: missing cityDocId for city \(city.name)")
            return .empty()
        }

        print("City popularity increment queued for city \(city.name), cityDocId: \(cityDocId)")
        return increaseCityPopularityUseCase.execute(cityId: cityDocId)
            .asCompletable()
    }
}
