//
//  TripsViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RealmSwift
internal import Realm

final class TripsViewController: BaseViewController {

    // MARK: - UI Components
    private let headerView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "소중한 여행 기록들"
        label.font = .boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "당신만의 특별한 추억들을 간직하세요"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        label.textAlignment = .center
        return label
    }()
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private let viewModel = TripsViewModel()
    private let disposeBag = DisposeBag()
    private let realm = try! Realm()
    private var cityToken: NotificationToken?
    private let tripSelectedRelay = PublishRelay<TravelTable>()
    private lazy var emptyView = CustomEmptyView()
    
    // MARK: - Lifecycle
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureTableHeaderView()
        CityImageBackfillService.shared.backfillMissingCityImages()
        observeCityImageChangesIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cityToken?.invalidate()
        cityToken = nil
    }
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        view.addSubview(tableView)
        view.addSubview(emptyView)
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        tableView.register(TripCardCell.self, forCellReuseIdentifier: TripCardCell.identifier)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        tableView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        // header 내부 layout은 SnapKit 유지
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(16)
            $0.centerX.equalToSuperview()
        }
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
        }
        
        emptyView.snp.makeConstraints { make in
            make.center.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
    }
    
    // MARK: - View Setup
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "나의 여행"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add)
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        
        headerView.backgroundColor = .clear
        
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "trip_rightBarButtonItem_btn"
        
        emptyView.configure(icon: UIImage(systemName: "airplane.departure"), iconTint: .white, gradientStyle: .bluePurple, title: "아직 여행 계획이 없어요", subtitle: "새로운 여행을 계획하고\n멋진 추억을 만들어보세요", buttonTitle: "첫 여행 계획하기", buttonImage: UIImage(systemName: "map"), buttonGradient: .bluePurple)
    }
    
    // MARK: - Binding
    override func configureBind() {
        let input = TripsViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
                .map { _ in () },
            tripDelete: tableView.rx.modelDeleted(TripSummary.self)
        )
        
        let output = viewModel.transform(input: input)
        
        output.tripsRelay
            .drive(tableView.rx.items(
                cellIdentifier: TripCardCell.identifier,
                cellType: TripCardCell.self
            )) { [weak self] index, element, cell in
                guard let self = self else { return }
                cell.configure(with: element.trip, journalCount: element.journalCount)
                
                cell.continueButton.rx.tap
                    .map { element.trip }
                    .bind(to: self.tripSelectedRelay)
                    .disposed(by: cell.disposeBag)
            }
            .disposed(by: disposeBag)
        
        output.tripsRelay
            .drive(with: self) { owner, trips in
                owner.headerView.isHidden = trips.isEmpty
                owner.emptyView.isHidden = !trips.isEmpty // isHidden으로 제어
                owner.tableView.isScrollEnabled = !trips.isEmpty
            }
            .disposed(by: disposeBag)
        
        tripSelectedRelay
            .throttle(.milliseconds(700), scheduler: MainScheduler.instance)
            .bind(with: self) { owner, trip in
                let vc = JournalTimelineViewController(tripId: trip.id)
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
        
        navigationItem.rightBarButtonItem?.rx.tap
            .bind(with: self) { owner, _ in
                let vc = TravelAddViewController()
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
        
        output.toastRelay
            .emit(with: self) { owner, message in
                print("삭제 실패: \(message)")
            }
            .disposed(by: disposeBag)

        emptyView.actionButton.rx.tap
            .bind(with: self) { owner, _ in
                let vc = TravelAddViewController()
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)

        SimpleNetworkState.shared.isConnectedDriver
            .distinctUntilChanged()
            .filter { $0 }
            .drive(onNext: { _ in
                CityImageBackfillService.shared.backfillMissingCityImages()
            })
            .disposed(by: disposeBag)
    }

    private func observeCityImageChangesIfNeeded() {
        guard cityToken == nil else { return }
        cityToken = realm.objects(CityTable.self).observe { [weak self] change in
            guard let self else { return }
            switch change {
            case .initial:
                break
            case .update:
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .error:
                break
            }
        }
    }
    
    // MARK: - Header Configuration (Frame 기반)
    private func configureTableHeaderView() {
        // SnapKit 내부 Layout 확정
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        
        // title + subtitle + spacing + padding 계산
        let titleHeight = titleLabel.intrinsicContentSize.height
        let subtitleHeight = subtitleLabel.intrinsicContentSize.height
        let topPadding: CGFloat = 16
        let spacing: CGFloat = 4
        let bottomPadding: CGFloat = 16
        
        let totalHeight = titleHeight + subtitleHeight + topPadding + spacing + bottomPadding
        
        // frame 기반으로 headerView 높이 지정
        headerView.frame = CGRect(
            x: 0,
            y: 0,
            width: tableView.bounds.width,
            height: totalHeight
        )
        
        tableView.tableHeaderView = headerView
    }
}

// MARK: - Extensions
extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}
