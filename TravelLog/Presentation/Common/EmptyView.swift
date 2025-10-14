//
//  EmptyView.swift
//  TravelLog
//
//  Created by 이상민 on 10/9/25.
//

import UIKit
import SnapKit

final class EmptyView: BaseView {
    
    // MARK: - UI
    private let iconContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .darkGray
        label.textAlignment = .center
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 8
        return view
    }()
    
    // MARK: - Init
    init(
        iconName: String? = nil,
        title: String,
        subtitle: String? = nil
    ) {
        super.init(frame: .zero)
        
        // setup
        if let iconName {
            iconView.image = UIImage(systemName: iconName)
        } else {
            iconView.isHidden = true
            iconContainerView.isHidden = true
        }
        
        titleLabel.text = title
        
        if let subtitle {
            subtitleLabel.text = subtitle
        } else {
            subtitleLabel.isHidden = true
        }
    }
    
    override func configureHierarchy() {
        iconContainerView.addSubview(iconView)
        addSubview(stackView)
        [iconContainerView, titleLabel, subtitleLabel].forEach { stackView.addArrangedSubview($0) }
    }
    
    override func configureLayout() {
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(32)
        }
        
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        
        iconContainerView.snp.makeConstraints { make in
            make.size.equalTo(40)
        }
    }
    
    override func configureView() {
        backgroundColor = .clear
    }
}
