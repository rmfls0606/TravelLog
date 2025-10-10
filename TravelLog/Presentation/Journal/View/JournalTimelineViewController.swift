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
    private let emptyView = EmptyView(
        iconName: "pencil",
        title: "아직 기록이 없어요",
        subtitle: "첫 번째 추억을 기록해보세요"
    )
    
    private let viewModel: JournalTimelineViewModel
    private let disposeBag = DisposeBag()
    private let realm = try! Realm()
    
    private var groupedData: [(date: Date, blocks: [JournalBlockTable])] = []
    private var trip: TravelTable?
    
    // MARK: - Init
    init(tripId: ObjectId) {
        self.viewModel = JournalTimelineViewModel(tripId: tripId)
        super.init(nibName: nil, bundle: nil)
        fetchTrip(tripId)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Trip Fetch
    private func fetchTrip(_ tripId: ObjectId) {
        if let trip = realm.object(ofType: TravelTable.self, forPrimaryKey: tripId) {
            self.trip = trip
            title = trip.destination?.name ?? "여행 기록"
        } else {
            title = "여행 기록"
        }
    }
    
    // MARK: - View Setup
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
    
    // MARK: - Bind
    override func configureBind() {
        let input = JournalTimelineViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () },
            addTapped: addButton.rx.tap.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        // ✅ 일지 목록 표시
        output.journals
            .drive(with: self) { owner, journals in
                owner.updateGroupedData(from: journals)
                owner.tableView.reloadData()
                owner.emptyView.isHidden = !journals.isEmpty
                owner.tableView.isHidden = journals.isEmpty
            }
            .disposed(by: disposeBag)
        
        // ✅ “추가하기” 버튼 → JournalAddViewController로 이동
        output.navigateToAdd
            .emit(with: self) { owner, tripId in
                let addViewModel = JournalAddViewModel(tripId: tripId)
                let addVC = JournalAddViewController(viewModel: addViewModel)
                addVC.hidesBottomBarWhenPushed = true
                owner.navigationController?.pushViewController(addVC, animated: true)
            }
            .disposed(by: disposeBag)
    }
}

// MARK: - UITableView
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
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: JournalTextCell.identifier,
            for: indexPath
        ) as? JournalTextCell else {
            return UITableViewCell()
        }
        cell.configure(with: groupedData[indexPath.section].blocks[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat { 50 }
    
    // ✅ 스와이프 삭제 기능 추가 (Realm journal 정리 포함)
    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            guard let self = self else { return }
            let block = self.groupedData[indexPath.section].blocks[indexPath.row]
            
            do {
                try self.realm.write {
                    // ✅ block 삭제 전에 journal 참조를 미리 잡아둔다
                    let journal = block.journal.first
                    
                    // 1️⃣ 블록 먼저 삭제
                    self.realm.delete(block)
                    
                    // 2️⃣ 블록 삭제 이후, journal의 남은 블록이 없으면 journal도 삭제
                    if let journal, journal.isInvalidated == false, journal.blocks.isEmpty {
                        self.realm.delete(journal)
                    }
                }
                
                // ✅ UI 업데이트 (Realm write 밖에서)
                self.groupedData[indexPath.section].blocks.remove(at: indexPath.row)
                
                if self.groupedData[indexPath.section].blocks.isEmpty {
                    self.groupedData.remove(at: indexPath.section)
                    tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
                } else {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                
                if self.groupedData.isEmpty {
                    self.emptyView.isHidden = false
                    self.tableView.isHidden = true
                }
                
                completion(true)
            } catch {
                print("❌ 삭제 실패: \(error)")
                completion(false)
            }
        }
        
        deleteAction.backgroundColor = .systemRed
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    // MARK: - Grouping Logic
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
