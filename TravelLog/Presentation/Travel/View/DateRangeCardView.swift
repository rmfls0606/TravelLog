//
//  DateRangeCardView.swift
//  TravelLog
//
//  Created by 이상민 on 10/1/25.
//

import UIKit
import SnapKit

enum QUickSelectOption: String, CaseIterable{
    case oneNightTwoDays = "1박 2일"
    case twoNightsThreeDays = "2박 3일"
    case threeNightsFourDays = "3박 4일"
    case oneWeek = "1주일"
    
    var days: Int{
        switch self {
        case .oneNightTwoDays:
            return 2
        case .twoNightsThreeDays:
            return 3
        case .threeNightsFourDays:
            return 4
        case .oneWeek:
            return 7
        }
    }
}

final class DateRangeCardView: BaseCardView {
    // MARK: - Header
    private let headerStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
        return view
    }()
    
    private let headerIcon: UIImageView = {
        let view = UIImageView()
        view.image =  UIImage(systemName: "calendar")
        view.tintColor = .systemBlue
        return view
    }()
    
    private let headerTitle: UILabel = {
        let label = UILabel()
        label.text = "여행 기간"
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    // MARK: - Select Box
    private let dashedBox: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.2)
        return view
    }()
    
    private let dashedLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGray4.cgColor
        layer.lineDashPattern = [4, 4]
        layer.fillColor = UIColor.clear.cgColor
        return layer
    }()
    
    // 안내 상태 (날짜 선택 전)
    private let placeholderStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 6
        return view
    }()
    
    private let placeholderIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "calendar")
        view.tintColor = .systemGray3
        return view
    }()
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "여행 날짜를 선택하세요\n출발일과 도착일을 한번에 설정"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    // 날짜 상태 (날짜 선택 후)
    private let dateStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 12
        view.isHidden = true
        view.distribution = .fillProportionally
        return view
    }()
    
    //출발일
    private let departStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .leading
        view.spacing = 8
        return view
    }()
    
    private let departTitle: UILabel = {
        let label = UILabel()
        label.text = "출발"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemBlue
        return label
    }()
    
    private let departDateLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .black
        return label
    }()
    
    //교통수단
    private let transportIconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let transportIcon: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "airplane")
        view.tintColor = .white
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    //도착일
    private let arriveStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .trailing
        view.spacing = 8
        return view
    }()
    
    private let arriveTitle: UILabel = {
        let label = UILabel()
        label.text = "도착"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemBlue
        return label
    }()
    
    private let arriveDateLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .black
        return label
    }()
    
    private let tripDateStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.distribution = .equalSpacing
        return view
    }()
    
    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue.withAlphaComponent(0.2)
        return view
    }()
    
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .systemBlue
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - 빠른 선택
    private let quickSelectTitle: UILabel = {
        let label = UILabel()
        label.text = "빠른 선택"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .darkGray
        return label
    }()
    
    private let quickSelectStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 8
        view.distribution = .fillEqually
        return view
    }()
    
    private(set) var quickButtons: [UIButton] = []
    
    // MARK: - Gesture
    let tapGesture = UITapGestureRecognizer()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        dashedLayer.path = UIBezierPath(
            roundedRect: dashedBox.bounds,
            cornerRadius: 12
        ).cgPath
        dashedLayer.frame = dashedBox.bounds
    }
    
    override func configureHierarchy() {
        headerStack.addArrangedSubview(headerIcon)
        headerStack.addArrangedSubview(headerTitle)
        
        placeholderStack.addArrangedSubview(placeholderIcon)
        placeholderStack.addArrangedSubview(placeholderLabel)
        
        dashedBox.addSubview(placeholderStack)
        
        departStack.addArrangedSubview(departTitle)
        departStack.addArrangedSubview(departDateLabel)
        
        arriveStack.addArrangedSubview(arriveTitle)
        arriveStack.addArrangedSubview(arriveDateLabel)
        
        tripDateStack.addArrangedSubview(departStack)
        
        transportIconContainer.addSubview(transportIcon)
        tripDateStack.addArrangedSubview(transportIconContainer)

        tripDateStack.addArrangedSubview(arriveStack)
        
        dateStack.addArrangedSubview(tripDateStack)
        
        dateStack.addArrangedSubview(lineView)
        
        dateStack.addArrangedSubview(durationLabel)
        
        dashedBox.addSubview(dateStack)
        
        addSubview(headerStack)
        addSubview(dashedBox)
        addSubview(quickSelectTitle)
        addSubview(quickSelectStack)
    }
    
    override func configureLayout() {
        headerStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.leading.equalToSuperview().inset(22)
        }

        headerIcon.snp.makeConstraints { make in
            make.size.equalTo(20)
        }
        
        dashedBox.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(22)
            make.height.equalTo(140)
        }
        
        placeholderStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        placeholderIcon.snp.makeConstraints { make in
            make.size.equalTo(28)
        }
        
        dateStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        tripDateStack.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
        }
        
        transportIconContainer.snp.makeConstraints { make in
            make.size.equalTo(32)
        }
        
        transportIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(16)
        }
        
        lineView.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
            make.height.equalTo(1)
        }
        
        durationLabel.snp.makeConstraints { make in
            make.bottom.horizontalEdges.equalToSuperview()
        }
        
        quickSelectTitle.snp.makeConstraints { make in
            make.top.equalTo(dashedBox.snp.bottom).offset(16)
            make.leading.equalToSuperview().inset(22)
        }
        
        quickSelectStack.snp.makeConstraints { make in
            make.top.equalTo(quickSelectTitle.snp.bottom).offset(8)
            make.horizontalEdges.equalToSuperview().inset(22)
            make.bottom.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }
    }
    
    override func configureView() {
        super.configureView()
        dashedBox.addGestureRecognizer(tapGesture)
        
        // Dashed Box
        dashedBox.layer.addSublayer(dashedLayer)
        
        QUickSelectOption.allCases.forEach { option in
            let button = UIButton(type: .system)
            button.setTitle(option.rawValue, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            button.backgroundColor = .systemGray6
            button.layer.cornerRadius = 8
            button.setTitleColor(.darkGray, for: .normal)
            quickButtons.append(button)
            quickSelectStack.addArrangedSubview(button)
        }
    }
    
    func updateRange(start: Date?, end: Date?){
        guard let start, let end else { return }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        
        departDateLabel.text = formatter.string(from: start)
        arriveDateLabel.text = formatter.string(from: end)
        
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        durationLabel.text = "\(days + 1)일 여행"
        
        placeholderStack.isHidden = true
        dateStack.isHidden = false
        
        dashedLayer.lineDashPattern = nil //점선 해제
        dashedLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.2).cgColor
        dashedLayer.lineWidth = 1.0
        
        dashedBox.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        
        dashedLayer.path = UIBezierPath(roundedRect: dashedBox.bounds, cornerRadius: 12).cgPath
    }
    
    func updateTransportIcon(name: String){
        transportIcon.image = UIImage(systemName: name)
    }
}
