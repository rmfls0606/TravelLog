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
    private let addButton = UIButton()
    private let subtitleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    private let viewModel = TripsViewModel()
    private let disposeBag = DisposeBag()
    
    override func configureHierarchy() {
        view.addSubviews(titleLabel, addButton, subtitleLabel, tableView)
        tableView.register(TripTextCell.self, forCellReuseIdentifier: TripTextCell.identifier)
    }
    
    override func configureLayout() {
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            $0.horizontalEdges.equalTo(view.safeAreaLayoutGuide).inset(16)
        }
        
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.horizontalEdges.equalTo(titleLabel)
        }
        
        tableView.snp.makeConstraints {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            $0.horizontalEdges.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.title = "나의 여행"
        let rightBarButton = UIBarButtonItem(systemItem: .add)
        navigationItem.rightBarButtonItem = rightBarButton
        
        titleLabel.text = "소중한 여행 기록들"
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "당신만의 특별한 추억들을 간직하세요"
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .gray
        subtitleLabel.textAlignment = .center
        
//        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
//        addButton.tintColor = .systemBlue
        
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
    }
    
    override func configureBind() {
        let input = TripsViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () },
            tripSelected: tableView.rx.modelSelected(TravelTable.self).asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output.trips
            .drive(tableView.rx.items(
                cellIdentifier: TripTextCell.identifier,
                cellType: TripTextCell.self)
            ) { _, trip, cell in
                cell.configure(with: trip)
            }
            .disposed(by: disposeBag)

        navigationItem.rightBarButtonItem?.rx.tap
            .bind(with: self) { owner, _ in
                let vc = TravelAddViewController()
                owner.navigationController?.pushViewController(vc, animated: true)
            }
            .disposed(by: disposeBag)
    }
}

extension UIView {
    /// 여러 개의 서브뷰를 한 번에 추가할 수 있는 헬퍼 메서드
    func addSubviews(_ views: UIView...) {
        views.forEach { addSubview($0) }
    }
}
