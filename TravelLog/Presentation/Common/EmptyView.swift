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
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 12
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
            iconView.tintColor = .systemGray3
            iconView.contentMode = .scaleAspectFit
        } else {
            iconView.isHidden = true
        }
        
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = .darkGray
        titleLabel.textAlignment = .center
        
        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.font = .systemFont(ofSize: 14)
            subtitleLabel.textColor = .gray
            subtitleLabel.numberOfLines = 0
            subtitleLabel.textAlignment = .center
        } else {
            subtitleLabel.isHidden = true
        }
    }
    
    override func configureHierarchy() {
        addSubview(stackView)
        [iconView, titleLabel, subtitleLabel].forEach { stackView.addArrangedSubview($0) }
    }
    
    override func configureLayout() {
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(32)
        }
        
        iconView.snp.makeConstraints { make in
            make.size.equalTo(60)
        }
    }
    
    override func configureView() {
        backgroundColor = .clear
    }
}
