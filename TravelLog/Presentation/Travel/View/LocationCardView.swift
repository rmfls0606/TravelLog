//
//  LocationCardView.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import UIKit
import SnapKit

final class LocationCardView: BaseCardView {
    
    let tapGesture = UITapGestureRecognizer()
    
    private let contentView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemGreen
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
        return label
    }()
    
    private let rightIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "chevron.right")
        view.tintColor = .darkGray
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    init(title: String, placeholder: String, icon: String) {
        super.init(frame: .zero)
        
        titleLabel.text = title
        valueLabel.text = placeholder
        iconView.image = UIImage(systemName: icon)
    }
    
    override func configureHierarchy() {
        addSubview(contentView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        
        addSubview(iconView)
        addSubview(contentView)
        addSubview(rightIcon)
    }
    
    override func configureLayout() {
        iconView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
            make.leading.equalToSuperview().offset(16)
        }
        
        contentView.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.trailing.equalTo(rightIcon.snp.leading).offset(-16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.horizontalEdges.equalToSuperview()
        }

        valueLabel.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().inset(16)
        }
        
        rightIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
            make.size.equalTo(14)
        }
    }
    
    override func configureView() {
        super.configureView()
        
        backgroundColor = .white
        addGestureRecognizer(tapGesture)
    }
    
    func updateValue(_ text: String) {
        valueLabel.text = text
        valueLabel.textColor = .black
    }
}
