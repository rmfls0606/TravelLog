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
        field.backgroundColor = .systemGray5
        
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
        table.rowHeight = 100
        return table
    }()
    
    private lazy var emptyView = EmptyView(
        iconName: "magnifyingglass",
        title: "검색 결과가 없습니다.",
        subtitle: "도시 이름을 입력해보세요.\n단어가 한글 혹은 영어로 정확한지 확인해보세요."
    )
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        view.addSubview(searchField)
        view.addSubview(tableView)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        searchField.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchField.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - View
    override func configureView() {
        navigationItem.title = "여행 도시 선택"
        view.backgroundColor = .systemGray6
        tableView.register(CityTableViewCell.self, forCellReuseIdentifier: CityTableViewCell.identifier)
    }
    
    // MARK: - Binding
    override func configureBind() {
        let input = DestinationViewModel.Input(
            searchCityText: searchField.rx.text.orEmpty
        )
        let output = viewModel.transform(input: input)
        
        output.filteredCities
            .drive(tableView.rx.items(
                cellIdentifier: CityTableViewCell.identifier,
                cellType: CityTableViewCell.self
            )) { _, city, cell in
                cell.configure(with: city)
            }
            .disposed(by: disposeBag)
        
        output.filteredCities
            .drive(with: self) { owner, cities in
                if cities.isEmpty {
                    owner.tableView.backgroundView = owner.emptyView
                } else {
                    owner.tableView.backgroundView = nil
                }
            }
            .disposed(by: disposeBag)
        
        tableView.rx.modelSelected(City.self)
            .bind(with: self) { owner, city in
                owner.selectedCity.accept(city)
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
    }
}

