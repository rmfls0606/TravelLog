//
//  JournalAddFooterView.swift
//  TravelLog
//
//  Created by 이상민 on 10/19/25.
//

import UIKit
import SnapKit

final class JournalAddFooterView: UITableViewHeaderFooterView {
    
    static let identifier = "JournalAddFooterView"
    let tapGesture = UITapGestureRecognizer()
    
    // MARK: - UI Components
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let plusInsideDot = UIImageView()
    
    private let containerView = UIView()
    private let dashedBorderLayer = CAShapeLayer()
    
    private let plusBadge = UIView()
    private let plusBadgeIcon = UIImageView()
    private let titleLabel = UILabel()
    private let contentContainer = UIView() // 중앙 배치용 컨테이너
    
    // MARK: - Init
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    // MARK: - Setup
    private func setupView() {
        contentView.backgroundColor = .clear
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        
        // MARK: 색상 팔레트
        let gradientBlue = UIColor(red: 88/255, green: 140/255, blue: 255/255, alpha: 1)
        let gradientPurple = UIColor(red: 130/255, green: 85/255, blue: 255/255, alpha: 1)
        _ = UIColor(red: 236/255, green: 239/255, blue: 255/255, alpha: 0.8)
        
        // MARK: 타임라인 선
        timelineLine.backgroundColor = UIColor.systemGray5
        contentView.addSubview(timelineLine)
        timelineLine.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(24)
            $0.width.equalTo(2)
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview().inset(16)
        }
        
        // MARK: Dot (+)
        dotView.backgroundColor = gradientPurple
        dotView.layer.cornerRadius = 8
        contentView.addSubview(dotView)
        dotView.snp.makeConstraints {
            $0.centerX.equalTo(timelineLine)
            $0.top.equalToSuperview().inset(20)
            $0.size.equalTo(16)
        }
        
        plusInsideDot.image = UIImage(systemName: "plus")
        plusInsideDot.tintColor = .white
        dotView.addSubview(plusInsideDot)
        plusInsideDot.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(10)
        }
        
        // MARK: 카드 컨테이너
        containerView.backgroundColor = .clear
        containerView.layer.cornerRadius = 14
        containerView.layer.addSublayer(dashedBorderLayer)
        containerView.isUserInteractionEnabled = true
        containerView.addGestureRecognizer(tapGesture)
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.leading.equalTo(timelineLine.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().inset(16)
        }
        
        // MARK: 내부 콘텐츠 컨테이너 (정중앙)
        containerView.addSubview(contentContainer)
        contentContainer.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        
        // MARK: Plus 배지
        plusBadge.backgroundColor = gradientBlue.withAlphaComponent(0.18)
        plusBadge.layer.cornerRadius = 10
        contentContainer.addSubview(plusBadge)
        plusBadge.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.size.equalTo(24)
        }
        
        plusBadgeIcon.image = UIImage(systemName: "plus")
        plusBadgeIcon.tintColor = gradientPurple
        plusBadge.addSubview(plusBadgeIcon)
        plusBadgeIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(11)
        }
        
        // MARK: Label
        titleLabel.text = "이 시점에 추억 추가하기"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = gradientPurple
        contentContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(plusBadge.snp.trailing).offset(8)
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        dashedBorderLayer.strokeColor = UIColor(
            red: 120/255, green: 130/255, blue: 255/255, alpha: 0.7
        ).cgColor
        dashedBorderLayer.fillColor = nil
        dashedBorderLayer.lineDashPattern = [5, 3]
        dashedBorderLayer.lineWidth = 1.2
        dashedBorderLayer.path = UIBezierPath(
            roundedRect: containerView.bounds,
            cornerRadius: 14
        ).cgPath
    }
}
