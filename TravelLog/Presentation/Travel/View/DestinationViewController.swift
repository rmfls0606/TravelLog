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
    private let disposeBag = DisposeBag()
    private let viewModel = DestinationViewModel()
    
    private let searchField: UITextField = {
        let field = UITextField()
        field.placeholder = "공항명 또는 도시명 검색"
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1.0
        field.layer.borderColor = UIColor.systemBlue.cgColor
        field.font = .systemFont(ofSize: 14)
        field.tintColor = .systemBlue
        field.clearButtonMode = .whileEditing
        field.textColor = .darkGray
        field.leftViewMode = .always
        field.rightViewMode = .always

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
        table.rowHeight = 70
        return table
    }()
    
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
        view.backgroundColor = .white
        tableView.register(CityTableViewCell.self, forCellReuseIdentifier: CityTableViewCell.identifier)
    }
    
    // MARK: - Binding
    override func configureBind() {
        let input = DestinationViewModel.Input()
        let output = viewModel.transform(input: input)
        
        output.cities
                    .drive(tableView.rx.items(
                        cellIdentifier: CityTableViewCell.identifier,
                        cellType: CityTableViewCell.self
                    )) { _, city, cell in
                        cell.configure(with: city)
                    }
                    .disposed(by: disposeBag)
    }
}

