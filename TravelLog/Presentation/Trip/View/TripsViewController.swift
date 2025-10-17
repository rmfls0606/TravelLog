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

final class TripsViewController: BaseViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private let viewModel = TripsViewModel()
    private let disposeBag = DisposeBag()
    
    // 버튼 클릭 시 trip 전달용 Relay
    private let tripSelectedRelay = PublishRelay<TravelTable>()
    
    // MARK: - View Setup
    override func configureHierarchy() {
        view.addSubviews(titleLabel, subtitleLabel, tableView)
        tableView.register(TripCardCell.self, forCellReuseIdentifier: TripCardCell.identifier)
    }
    
    override func configureLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.centerX.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
        }
        
        tableView.snp.makeConstraints {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            $0.horizontalEdges.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        navigationItem.title = "나의 여행"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add)
        
        titleLabel.text = "소중한 여행 기록들"
        titleLabel.font = .boldSystemFont(ofSize: 16)
        subtitleLabel.text = "당신만의 특별한 추억들을 간직하세요"
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .gray
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
    }
    
    // MARK: - Binding
    override func configureBind() {
        let input = TripsViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:)))
                .map { _ in () },
            tripDelete: tableView.rx.modelDeleted(TravelTable.self)
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
            .emit(with: self){ owner, message in
                print("삭제 실패: \(message)")
            }
            .disposed(by: disposeBag)
    }
}

extension UIView {
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}
