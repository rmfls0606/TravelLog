//
//  JournalLinkBlockView.swift
//  TravelLog
//
//  Created by 이상민 on 10/21/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class JournalLinkBlockView: BaseView, UITextFieldDelegate {
    
    // MARK: - UI
    private let headerStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 6
        return view
    }()
    
    private let typeIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemGreen
        view.image = UIImage(systemName: "link")
        return view
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.text = "링크"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        label.text = formatter.string(from: Date())
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        return label
    }()
    
    private(set) var removeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .systemGray3
        return btn
    }()
    
    private let linkContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.tintColor = UIColor.darkGray.withAlphaComponent(0.6)
        view.image = UIImage(systemName: "globe")
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let inputStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
        return view
    }()
    
    private let urlTextField: UITextField = {
        let textField = UITextField()
        
        let placeholderText = "링크 URL을 입력하세요"
        
        let placeholderAttr = NSAttributedString(string: placeholderText, attributes: [
            .foregroundColor: UIColor.darkGray.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 14)
        ])
        textField.attributedPlaceholder = placeholderAttr
        
        textField.isUserInteractionEnabled = true
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 14)
        
        return textField
    }()
    
    private(set) var disposeBag = DisposeBag()
    
    // 닫기 버튼이 눌렸을 때 발생하는 ControlEvent
    var removeTapped: ControlEvent<Void> {
        return removeButton.rx.tap
    }
    
    // 현재 입력 필드의 텍스트 Observable
    var urlText: ControlProperty<String?> {
        return urlTextField.rx.text
    }
    
    override func configureHierarchy() {
        addSubview(headerStack)
        addSubview(linkContainer)
        
        // Header Setup
        headerStack.addArrangedSubview(typeIcon)
        headerStack.addArrangedSubview(typeLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(removeButton)

        // Link Container Setup
        linkContainer.addSubview(inputStackView)
        inputStackView.addArrangedSubview(iconImageView)
        inputStackView.addArrangedSubview(urlTextField)
        
        urlTextField.delegate = self
    }
    
    override func configureLayout() {
        headerStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        linkContainer.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(urlTextField.snp.bottom).offset(12)
        }

        inputStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        self.snp.makeConstraints { make in
            make.bottom.equalTo(linkContainer.snp.bottom).offset(16)
        }
    }
    
    override func configureView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    func updateTimeLabel(with date: Date = Date()) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        timeLabel.text = formatter.string(from: date)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}
