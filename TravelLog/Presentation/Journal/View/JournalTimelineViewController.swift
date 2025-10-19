//
//  JournalTimelineViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RealmSwift

final class JournalTimelineViewController: BaseViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerContainer = UIView()
    private let tripImageView = UIImageView()
    private let cityLabel = UILabel()
    private let countryLabel = UILabel()
    
    private let addMemoryContainerView = UIView()
    private let addMemoryView = CustomEmptyView()
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // MARK: - Properties
    private let viewModel: JournalTimelineViewModel
    private let disposeBag = DisposeBag()
    private let realm = try! Realm()
    private var groupedData: [(date: Date, blocks: [JournalBlockTable])] = []
    private var trip: TravelTable?
    private let deleteTappedSubject = PublishSubject<(ObjectId, ObjectId)>()
    
    // MARK: - Init
    init(tripId: ObjectId) {
        self.viewModel = JournalTimelineViewModel(tripId: tripId)
        super.init(nibName: nil, bundle: nil)
        fetchTrip(tripId)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        addMemoryContainerView.applyGradient(
            style: .softBluePurple,
            start: CGPoint(x: 0, y: 0.5),
            end: CGPoint(x: 1, y: 0.5),
            cornerRadius: 16
        )
    }
    
    // MARK: - Trip Fetch
    private func fetchTrip(_ tripId: ObjectId) {
        if let trip = realm.object(ofType: TravelTable.self, forPrimaryKey: tripId) {
            self.trip = trip
            title = trip.destination?.name ?? "여행 기록"
        } else {
            title = "여행 기록"
        }
    }
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubviews(headerContainer, addMemoryContainerView, tableView)
        headerContainer.addSubviews(tripImageView, cityLabel, countryLabel)
        addMemoryContainerView.addSubview(addMemoryView)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
        
        headerContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(headerContainer.snp.width).multipliedBy(0.4)
        }
        
        tripImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        cityLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(countryLabel.snp.top).offset(-4)
        }
        
        countryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        
        addMemoryContainerView.snp.makeConstraints { make in
            make.top.equalTo(headerContainer.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        addMemoryView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(addMemoryContainerView.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - View Setup
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        
        headerContainer.clipsToBounds = true
        headerContainer.layer.cornerRadius = 12
        headerContainer.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        
        tripImageView.contentMode = .scaleAspectFill
        tripImageView.clipsToBounds = true
        tripImageView.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        tripImageView.image = .seoul
        
        cityLabel.font = .boldSystemFont(ofSize: 20)
        cityLabel.textColor = .white
        
        countryLabel.font = .systemFont(ofSize: 14, weight: .medium)
        countryLabel.textColor = .white.withAlphaComponent(0.9)
        
        if let trip = trip {
            cityLabel.text = trip.destination?.name ?? "-"
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy.MM.dd"
            countryLabel.text = "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
        }
        
        addMemoryView.configure(
            icon: UIImage(systemName: "plus"),
            iconTint: .white,
            gradientStyle: .bluePurple,
            title: "새로운 추억 기록하기",
            subtitle: "이 여행의 특별한 순간을 남겨보세요",
            buttonTitle: "추억 기록하기",
            buttonImage: UIImage(systemName: "rectangle.and.pencil.and.ellipsis"),
            buttonGradient: .bluePurple
        )
        
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        tableView.showsVerticalScrollIndicator = false
        tableView.register(JournalTextCell.self, forCellReuseIdentifier: JournalTextCell.identifier)
        tableView.register(JournalDateHeaderView.self, forHeaderFooterViewReuseIdentifier: JournalDateHeaderView.identifier)
        tableView.register(JournalAddFooterView.self, forHeaderFooterViewReuseIdentifier: JournalAddFooterView.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add)
    }
    
    // MARK: - Binding (Rx)
    override func configureBind() {
        let input = JournalTimelineViewModel.Input(
            viewWillAppear: rx.methodInvoked(#selector(UIViewController.viewWillAppear(_:))).map { _ in () },
            addTapped: addMemoryView.actionButton.rx.tap.asObservable(),
            deleteTapped: deleteTappedSubject.asObservable()
        )
        
        let output = viewModel.transform(input: input)
        
        output.journals
            .drive(with: self) { owner, journals in
                owner.updateGroupedData(from: journals)

                DispatchQueue.main.async {
                    let hasData = !journals.isEmpty

                    owner.addMemoryContainerView.isHidden = hasData
                    owner.tableView.isHidden = !hasData
                    owner.tableView.reloadData()
                    owner.tableView.layoutIfNeeded()

                    // 핵심: 데이터 있을 때는 tableView를 headerContainer 바로 아래로 붙이기
                    owner.tableView.snp.remakeConstraints { make in
                        if hasData {
                            make.top.equalTo(owner.headerContainer.snp.bottom).offset(16)
                        } else {
                            make.top.equalTo(owner.addMemoryContainerView.snp.bottom).offset(16)
                        }
                        make.horizontalEdges.equalToSuperview()
                        make.bottom.equalToSuperview()
                        make.height.equalTo(owner.tableView.contentSize.height)
                    }

                    // 전환 애니메이션
                    UIView.animate(withDuration: 0.25) {
                        owner.addMemoryContainerView.alpha = hasData ? 0 : 1
                        owner.tableView.alpha = hasData ? 1 : 0
                        owner.view.layoutIfNeeded()
                    }
                }
            }
            .disposed(by: disposeBag)
        
        output.navigateToAdd
            .bind(with: self) { owner, tripId in
                let addVM = JournalAddViewModel(tripId: tripId, date: Date())
                let addVC = JournalAddViewController(viewModel: addVM)
                addVC.hidesBottomBarWhenPushed = true
                owner.navigationController?.pushViewController(addVC, animated: true)
            }
            .disposed(by: disposeBag)
        
        navigationItem.rightBarButtonItem?.rx.tap
               .bind(with: self) { owner, _ in
                   guard let trip = owner.trip else { return }
                   let addVM = JournalAddViewModel(tripId: trip.id, date: Date())
                   let addVC = JournalAddViewController(viewModel: addVM)
                   addVC.hidesBottomBarWhenPushed = true
                   owner.navigationController?.pushViewController(addVC, animated: true)
               }
               .disposed(by: disposeBag)
        
        output.deleteCompleted
            .observe(on: MainScheduler.instance)
            .subscribe(with: self) { owner, _ in
                owner.tableView.reloadData()
            }
            .disposed(by: disposeBag)
    }
    
    // MARK: - Realm 삭제 로직
    private func deleteJournalBlock(at indexPath: IndexPath) {
        let block = groupedData[indexPath.section].blocks[indexPath.row]
        
        do {
            try realm.write {
                let journal = block.journal.first
                realm.delete(block)
                if let journal, !journal.isInvalidated, journal.blocks.isEmpty {
                    realm.delete(journal)
                }
            }
            
            groupedData[indexPath.section].blocks.remove(at: indexPath.row)
            
            if groupedData[indexPath.section].blocks.isEmpty {
                groupedData.remove(at: indexPath.section)
                tableView.deleteSections(IndexSet(integer: indexPath.section), with: .automatic)
            } else {
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        } catch {
            print("삭제 실패: \(error)")
        }
    }
    
    // MARK: - Grouping Logic
    private func updateGroupedData(from journals: [JournalTable]) {
        let blocks = journals.flatMap { $0.blocks }
        let grouped = Dictionary(grouping: blocks) { Calendar.current.startOfDay(for: $0.createdAt) }
        groupedData = grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, blocks: $0.value.sorted { $0.createdAt < $1.createdAt }) }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension JournalTimelineViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int { groupedData.count }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedData[section].blocks.count
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: JournalDateHeaderView.identifier
        ) as? JournalDateHeaderView
        header?.configure(date: groupedData[section].date)
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footer = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: JournalAddFooterView.identifier
        ) as? JournalAddFooterView else { return nil }
        
        footer.tapGesture.rx.event
                .throttle(.milliseconds(400), scheduler: MainScheduler.instance)
                .bind(with: self) { owner, _ in
                    guard let trip = owner.trip else { return }
                    let date = owner.groupedData[section].date
                    
                    let addVM = JournalAddViewModel(tripId: trip.id, date: date)
                    let addVC = JournalAddViewController(viewModel: addVM)
                    addVC.hidesBottomBarWhenPushed = true
                    owner.navigationController?.pushViewController(addVC, animated: true)
                }
                .disposed(by: footer.disposeBag)

        
        return footer
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 84 }
    
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
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? JournalTextCell else { return }
        let isFirst = (indexPath.section == 0 && indexPath.row == 0)
        cell.setIsFirstInTimeline(isFirst)
    }
}
extension JournalTimelineViewController {
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {

        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            guard let self else { return }
            let block = self.groupedData[indexPath.section].blocks[indexPath.row]
            guard let journal = block.journal.first else { return }

            // ViewModel에 삭제 요청 전달
            self.deleteTappedSubject.onNext((journal.id, block.id))
            completion(true)
        }

        deleteAction.backgroundColor = .systemRed
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
