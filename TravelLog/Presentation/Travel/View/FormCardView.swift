//
//  FormCardView.swift
//  TravelLog
//
//  Created by 이상민 on 9/30/25.
//

import UIKit
import SnapKit

enum FormCardType{
    case location(title: String, placeholder: String, icon: String)
    case date(title: String, placeholder: String)
}

final class FormCardView: BaseCardView {
    private let titleView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .darkGray
        return label
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        return view
    }()
    
    private let inputBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        return label
    }()
    
    private let rightIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        return view
    }()
    
    private let type: FormCardType
    
    init(type: FormCardType){
        self.type = type
        super.init(frame: .zero)
    }
    
    override func configureHierarchy() {
        addSubview(titleView)
        
        titleView.addSubview(iconView)
        titleView.addSubview(titleLabel)
        
        addSubview(inputBackground)
        
        inputBackground.addSubview(valueLabel)
        inputBackground.addSubview(rightIcon)
    }
    
    override func configureLayout() {
        titleView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(22)
        }
        
        iconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(20)
            make.bottom.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleView)
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.verticalEdges.equalToSuperview()
        }
        
        inputBackground.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom).offset(16)
            make.horizontalEdges.bottom.equalToSuperview().inset(22)
            make.height.equalTo(44)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.trailing.equalTo(rightIcon.snp.leading).offset(-8)
        }
        
        rightIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(12)
            make.size.equalTo(20)
        }
    }
    
    override func configureView() {
        super.configureView()
        backgroundColor = .white
        
        switch type {
        case .location(let title, let placeholder, let icon):
            titleLabel.text = title
            iconView.image = UIImage(systemName: icon)
            valueLabel.text = placeholder
            rightIcon.image = UIImage(systemName: "mappin.and.ellipse.circle")
        case .date(let title, let placeholder):
            titleLabel.text = title
            iconView.image = UIImage(systemName: "calendar")
            valueLabel.text = placeholder
            rightIcon.image = UIImage(systemName: "calendar")
        }
    }
}
