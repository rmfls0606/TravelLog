//
//  PhotoNavigationTitleView.swift
//  TravelLog
//
//  Created by 이상민 on 11/7/25.
//

import UIKit
import SnapKit

final class PhotoNavigationTitleView: UIView {

    private let navigationStackView: UIStackView = {
        let view = UIStackView()
        view.spacing = 4
        view.axis = .vertical
        view.alignment = .fill
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "최근 항목"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()
    
    private let selectedPhotoBox: UIView = {
        let view = UIView()
        view.isHidden = true
        view.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.systemBlue.cgColor
        return view
    }()
    
    private(set) var selectedPhotoLabel: UILabel = {
        let label = UILabel()
        label.text = "0개 선택 중"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10)
        label.textColor = .systemBlue
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        selectedPhotoBox.layoutIfNeeded()
        selectedPhotoBox.layer.cornerRadius = selectedPhotoBox.frame.height / 2
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }
    
    private func configureHierarchy(){
        addSubviews(navigationStackView)
        navigationStackView.addArrangedSubview(titleLabel)
        
        selectedPhotoBox.addSubview(selectedPhotoLabel)
        navigationStackView.addArrangedSubview(selectedPhotoBox)
    }
    
    private func configureLayout(){
        navigationStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        selectedPhotoBox.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
        }
        
        selectedPhotoLabel.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview().inset(4)
            make.horizontalEdges.equalToSuperview().inset(10)
        }
    }
    
    func updateSelectedPhotoCount(_ count: Int, isSelecting: Bool){
        if isSelecting{
            selectedPhotoBox.isHidden = false
            selectedPhotoLabel.text = "\(count)개 선택 중"
        }else{
            selectedPhotoBox.isHidden = true
        }
    }
}
