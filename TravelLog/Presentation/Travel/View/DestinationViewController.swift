//
//  DestinationViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/5/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class DestinationSelectorViewController: BaseViewController {
    private(set) var disposeBag = DisposeBag()
    private let viewModel = DestinationViewModel()
    
    let selectedCity = PublishRelay<City>()

    private var currentQuery: String = ""
    
    private let searchField: UITextField = {
        let field = UITextField()
        field.placeholder = "도시명 검색"
        field.layer.cornerRadius = 12
        field.font = .systemFont(ofSize: 14)
        field.tintColor = .systemBlue
        field.clearButtonMode = .whileEditing
        field.textColor = .darkGray
        field.leftViewMode = .always
        field.rightViewMode = .always
        field.backgroundColor = .systemGray6
        field.accessibilityIdentifier = "travel_city_field"
        
        let iconContainer = UIView(frame: CGRect(x: 0, y: 0, width: 48, height: 20))
        let leftIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        leftIcon.tintColor = .gray
        leftIcon.contentMode = .scaleAspectFit
        leftIcon.frame = CGRect(x: 12, y: 0, width: 20, height: 20)
        iconContainer.addSubview(leftIcon)
        
        field.leftView = iconContainer
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 32, height: 20))
        field.rightView = rightPaddingView
        
        field.borderStyle = .none
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        return field
    }()
    
    private let tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = 60
        return table
    }()

    private let sectionHeaderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let sectionBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 8
        return view
    }()

    private let sectionBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .systemBlue
        label.text = "POPULAR"
        return label
    }()

    private let sectionTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .black
        label.text = "인기 도시"
        return label
    }()
    
    private lazy var emptyView = EmptyView(
        iconName: "magnifyingglass",
        title: "검색 결과가 없습니다.",
        subtitle: "도시 이름을 입력해보세요.\n단어가 한글 혹은 영어로 정확한지 확인해보세요."
    )
    
    private lazy var tapGesture = UITapGestureRecognizer()
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        view.addSubview(searchField)
        view.addSubview(sectionHeaderView)
        sectionHeaderView.addSubview(sectionBadgeView)
        sectionBadgeView.addSubview(sectionBadgeLabel)
        sectionHeaderView.addSubview(sectionTitleLabel)
        view.addSubview(tableView)
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        searchField.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        sectionHeaderView.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
        }

        sectionBadgeView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(sectionTitleLabel.snp.trailing).offset(8)
            make.trailing.lessThanOrEqualToSuperview()
            make.height.equalTo(18)
        }

        sectionBadgeLabel.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview().inset(3)
            make.horizontalEdges.equalToSuperview().inset(7)
        }

        sectionTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalTo(sectionBadgeView)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(sectionHeaderView.snp.bottom).offset(8)
            make.horizontalEdges.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - View
    override func configureView() {
        navigationItem.title = "여행 도시 선택"
        view.backgroundColor = .white
        tapGesture.cancelsTouchesInView = false
        sectionHeaderView.isHidden = true
        tableView.register(CityTableViewCell.self, forCellReuseIdentifier: CityTableViewCell.identifier)
        tableView.register(CityShimmerTableViewCell.self,
                           forCellReuseIdentifier: CityShimmerTableViewCell.identifier)
    }
    
    // MARK: - Binding
    override func configureBind() {
        let input = DestinationViewModel.Input(
            searchCityText: searchField.rx.text.orEmpty,
        )
        let output = viewModel.transform(input: input)
        
        output.items
            .drive(tableView.rx.items) { tableView, row, item in
                switch item {
                case .skeleton:
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: CityShimmerTableViewCell.identifier,
                        for: IndexPath(row: row, section: 0)
                    ) as! CityShimmerTableViewCell
                    cell.start()
                    return cell
                case .city(let city):
                    let cell = tableView.dequeueReusableCell(
                        withIdentifier: CityTableViewCell.identifier,
                        for: IndexPath(row: row, section: 0)
                    ) as! CityTableViewCell
                    
                    cell.configure(with: city)
                    return cell
                }
            }
            .disposed(by: disposeBag)

        searchField.rx.text.orEmpty
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .bind(with: self) { owner, query in
                owner.currentQuery = query
            }
            .disposed(by: disposeBag)
        
        output.state
            .drive(with: self) { owner, state in
                owner.updateSectionHeader(for: state)
                switch state {
                case .idle:
                    owner.emptyView.configure(
                        iconName: "magnifyingglass",
                        title: "여행 도시를 입력해주세요.",
                        subtitle: "도시 이름을 검색해보세요."
                    )
                    owner.tableView.backgroundView = owner.emptyView
                case .loading:
                    owner.tableView.backgroundView = nil
                case .empty:
                    owner.emptyView.configure(
                        iconName: "magnifyingglass",
                        title: "검색 결과가 없습니다.",
                        subtitle: "단어가 정확한지 확인해보세요."
                    )
                    owner.tableView.backgroundView = owner.emptyView
                case .result:
                    owner.tableView.backgroundView = nil
                case .offline:
                    owner.emptyView.configure(
                        iconName: "wifi.slash",
                        title: "인터넷 연결이 필요합니다.",
                        subtitle: "새로운 도시를 검색하려면 네트워크에 연결해주세요."
                    )
                    owner.tableView.backgroundView = owner.emptyView
                }
            }
            .disposed(by: disposeBag)
        
        tableView.rx.modelSelected(CityCellItem.self)
            .compactMap { item -> City? in
                guard case let .city(city) = item else { return nil }
                return city
            }
            .bind(with: self) { owner, city in
                owner.selectedCity.accept(city)
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
        
        tapGesture.rx.event
            .bind(with: self) { owner, _ in
                owner.view.endEditing(true)
            }
            .disposed(by: disposeBag)
    }

    private func updateSectionHeader(for state: SearchState) {
        let isSearching = !currentQuery.isEmpty

        switch state {
        case .loading, .result:
            sectionHeaderView.isHidden = false
            if isSearching {
                sectionBadgeLabel.text = "RESULT"
                sectionBadgeView.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.1)
                sectionBadgeLabel.textColor = .systemTeal
                sectionTitleLabel.text = "검색 결과"
            } else {
                sectionBadgeLabel.text = "POPULAR"
                sectionBadgeView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
                sectionBadgeLabel.textColor = .systemBlue
                sectionTitleLabel.text = "인기 도시"
            }
        case .idle, .empty, .offline:
            sectionHeaderView.isHidden = true
        }
    }
}
