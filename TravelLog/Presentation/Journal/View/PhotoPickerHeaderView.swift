//
//  PhotoPickerHeaderView.swift
//  TravelLog
//
//  Created by 이상민 on 11/3/25.
//

import UIKit
import SnapKit

final class PhotoPickerHeaderView: UICollectionReusableView {
    static let identifier = "PhotoPickerHeaderView"
    
    var onSelectMore: (() -> Void)?
    var onOpenSetting: (() -> Void)?
    
    private let moreButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.background.cornerRadius = 0
        config.titleAlignment = .leading
        config.attributedTitle = AttributedString("더 많은 사진 선택", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 14)
        ]))
        config.baseForegroundColor = .black
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        return button
    }()
    
    private let lineViewContainer = UIView()
    
    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        return view
    }()
    
    private let settingButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.background.cornerRadius = 0
        config.titleAlignment = .leading
        config.baseForegroundColor = .black
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.attributedTitle = AttributedString("권한 설정으로 이동", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 14)
        ]))
        config.attributedSubtitle = AttributedString("사진 접근 권한을 \"모든 사진\"으로 변경할 수 있습니다.", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]))
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        return button
    }()
    
    private let buttonStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.distribution = .fill
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureHierarchy(){
        backgroundColor = .systemBackground
        addSubview(buttonStack)
        buttonStack.addArrangedSubview(moreButton)
        buttonStack.addArrangedSubview(lineViewContainer)
        lineViewContainer.addSubview(lineView)
        buttonStack.addArrangedSubview(settingButton)
    }
    
    private func configureLayout(){
        buttonStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        moreButton.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
        }
        
        lineViewContainer.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
        }
        
        lineView.snp.makeConstraints { make in
            make.height.equalTo(1)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        settingButton.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
        }
    }
    
    private func configureView(){
        moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)
        settingButton.addTarget(self, action: #selector(didTapSetting), for: .touchUpInside)
    }
    
    @objc
    private func didTapMore(){
        onSelectMore?()
    }
    
    @objc
    private func didTapSetting() {
        onOpenSetting?()
    }
}
