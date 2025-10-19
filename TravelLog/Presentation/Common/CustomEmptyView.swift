//
//  CustomEmptyView.swift
//  TravelLog
//
//  Created by 이상민 on 10/18/25.
//

import UIKit
import SnapKit

final class CustomEmptyView: BaseView {

    // MARK: - UI
    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.isHidden = true
        view.clipsToBounds = true
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray2
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    private(set) var actionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        var imageConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        config.cornerStyle = .fixed
        config.baseBackgroundColor = .clear // gradient 예정
        config.baseForegroundColor = .white
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)

        let button = UIButton(configuration: config)
        button.isHidden = true
        button.layer.cornerRadius = 8 // iconContainer와 동일
        button.clipsToBounds = true
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        addSubview(stackView)
        iconContainer.addSubview(iconImageView)
        stackView.addArrangedSubviews(iconContainer, titleLabel, subtitleLabel, actionButton)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        stackView.snp.makeConstraints {
            $0.verticalEdges.equalToSuperview().inset(16)
            $0.horizontalEdges.equalToSuperview().inset(16)
        }
        
        iconContainer.snp.makeConstraints {
            $0.size.equalTo(56)
        }
        
        iconImageView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(28)
        }

        actionButton.snp.makeConstraints {
            $0.height.equalTo(44) // 버튼 높이 통일
        }
    }
    
    // MARK: - Style
    override func configureView() {
        backgroundColor = .clear
    }
    
    // MARK: - Configure Content
    func configure(
        icon: UIImage? = nil,
        iconTint: UIColor = .systemGray3,
        gradientStyle: GradientStyle? = nil,
        title: String,
        subtitle: String? = nil,
        buttonTitle: String? = nil,
        buttonImage: UIImage? = nil,
        buttonGradient: GradientStyle? = nil
    ) {
        // 아이콘
        if let icon = icon {
            iconContainer.isHidden = false
            iconImageView.image = icon
            iconImageView.tintColor = iconTint
            
            if let gradientStyle {
                DispatchQueue.main.async {
                    self.iconContainer.applyGradient(style: gradientStyle, cornerRadius: 12)
                }
            }
        } else {
            iconContainer.isHidden = true
        }
        
        // 타이틀
        titleLabel.text = title
        
        // 서브타이틀
        if let subtitle = subtitle {
            subtitleLabel.isHidden = false
            subtitleLabel.text = subtitle
        } else {
            subtitleLabel.isHidden = true
        }
        
        // 버튼
        if let buttonTitle = buttonTitle {
            actionButton.isHidden = false
            
            var config = actionButton.configuration
            config?.title = buttonTitle
            config?.image = buttonImage
            config?.attributedTitle = AttributedString(
                buttonTitle,
                attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold)
                ])
            )
            actionButton.configuration = config
            
            if let buttonGradient {
                DispatchQueue.main.async {
                    self.actionButton.applyGradient(style: buttonGradient, cornerRadius: 12)
                }
            }
        } else {
            actionButton.isHidden = true
        }
    }
}

// MARK: - Convenience Extension
private extension UIStackView {
    func addArrangedSubviews(_ views: UIView...) {
        views.forEach { addArrangedSubview($0) }
    }
}
