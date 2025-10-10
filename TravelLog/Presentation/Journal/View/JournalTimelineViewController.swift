//
//  JournalTimelineViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit
import RealmSwift

final class JournalTimelineViewController: BaseViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let addButton = UIButton(type: .system)
    private let emptyView = EmptyView(iconName: "pencil", title: "아직 기록이 없어요", subtitle: "첫 번째 추억을 기록해보세요")
    private let viewModel: JournalTimelineViewModel
    private let disposeBag = DisposeBag()
    private let realm = try! Realm()
    private var groupedData: [(date: Date, blocks: [JournalBlockTable])] = []
    private var trip: TravelTable?
    
    init(tripId: ObjectId) {
        self.viewModel = JournalTimelineViewModel(tripId: tripId)
        super.init(nibName: nil, bundle: nil)
        self.fetchTrip(tripId: tripId)
    }
    
    private func fetchTrip(tripId: ObjectId) {
        if let trip = realm.object(ofType: TravelTable.self, forPrimaryKey: tripId) {
            self.trip = trip
            title = trip.destination?.name ?? "여행 기록"
        } else { title = "여행 기록" }
    }
    
    override func configureHierarchy() {
        view.addSubviews(tableView, addButton, emptyView)
    }
    
    override func configureLayout() {
        tableView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        addButton.snp.makeConstraints {
            $0.trailing.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
            $0.size.equalTo(60)
        }
        emptyView.snp.makeConstraints { $0.center.equalToSuperview() }
    }
    
    override func configureView() {
        view.backgroundColor = .white
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(JournalTextCell.self, forCellReuseIdentifier: JournalTextCell.identifier)
        tableView.register(JournalDateHeaderView.self, forHeaderFooterViewReuseIdentifier: JournalDateHeaderView.identifier)
        tableView.separatorStyle = .none
        addButton.backgroundColor = .systemBlue
        addButton.tintColor = .white
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.layer.cornerRadius = 30
        emptyView.isHidden = true
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func configureBind() {
        let input = JournalTimelineViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () },
            addTapped: addButton.rx.tap.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output.journals
            .drive(with: self) { owner, journals in
                owner.updateGroupedData(from: journals)
                owner.tableView.reloadData()
                owner.emptyView.isHidden = !journals.isEmpty
                owner.tableView.isHidden = journals.isEmpty
            }
            .disposed(by: disposeBag)
    }
}

extension JournalTimelineViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { groupedData.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedData[section].blocks.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: JournalDateHeaderView.identifier) as? JournalDateHeaderView
        header?.configure(date: groupedData[section].date)
        return header
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: JournalTextCell.identifier, for: indexPath) as? JournalTextCell else { return UITableViewCell() }
        cell.configure(with: groupedData[indexPath.section].blocks[indexPath.row])
        return cell
    }
    
    //    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { tableView.estimatedRowHeight }
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        50
    }
    
    private func updateGroupedData(from journals: [JournalTable]) {
        let blocks = journals.flatMap { $0.blocks }
        let grouped = Dictionary(grouping: blocks) { block in
            Calendar.current.startOfDay(for: block.createdAt)
        }
        groupedData = grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, blocks: $0.value.sorted { $0.createdAt < $1.createdAt }) }
    }
}
