//
//  JournalAddFooterView.swift
//  TravelLog
//
//  Created by 이상민 on 10/19/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class JournalAddFooterView: UITableViewHeaderFooterView {
    static let identifier = "JournalAddFooterView"
    
    // MARK: - Rx
    var disposeBag = DisposeBag()
    let tapGesture = UITapGestureRecognizer()
    
    // MARK: - UI
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let plusInsideDot = UIImageView()
    private let containerView = UIView()
    private let dashedBorderLayer = CAShapeLayer()
    
    private let plusBadge = UIView()
    private let plusBadgeIcon = UIImageView()
    private let titleLabel = UILabel()
    private let centerView = UIView()
    
    // MARK: - Init
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag() // footer 단위로 Rx 해제
    }

    // MARK: - Setup
    private func setupView() {
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        contentView.isUserInteractionEnabled = true
        
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear
        
        let gradientBlue = UIColor(red: 88/255, green: 140/255, blue: 255/255, alpha: 1)
        let gradientPurple = UIColor(red: 130/255, green: 85/255, blue: 255/255, alpha: 1)
        let softBG = UIColor(red: 236/255, green: 239/255, blue: 255/255, alpha: 0.8)
        
        // 타임라인
        timelineLine.backgroundColor = .systemGray5
        contentView.addSubview(timelineLine)
        timelineLine.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(24)
            $0.width.equalTo(2)
            $0.top.bottom.equalToSuperview()
        }
        
        // 도트
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
        
        // 컨테이너
        containerView.backgroundColor = softBG.withAlphaComponent(0.5)
        containerView.layer.cornerRadius = 14
        containerView.layer.addSublayer(dashedBorderLayer)
        containerView.isUserInteractionEnabled = true
        contentView.addSubview(containerView)
        
        containerView.snp.makeConstraints {
            $0.leading.equalTo(timelineLine.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().offset(16)
            $0.bottom.equalToSuperview().inset(8)
            $0.height.greaterThanOrEqualTo(60)
        }
        
        // 중앙 레이아웃
        containerView.addSubview(centerView)
        centerView.snp.makeConstraints { $0.center.equalToSuperview() }
        
        plusBadge.backgroundColor = gradientBlue.withAlphaComponent(0.18)
        plusBadge.layer.cornerRadius = 10
        centerView.addSubview(plusBadge)
        plusBadge.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.size.equalTo(24)
        }
        
        plusBadgeIcon.image = UIImage(systemName: "plus")
        plusBadgeIcon.tintColor = gradientPurple
        plusBadge.addSubview(plusBadgeIcon)
        plusBadgeIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(11)
        }
        
        titleLabel.text = "이 시점에 추억 추가하기"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = gradientPurple
        centerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(plusBadge.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview()
        }
        
        // TapGesture 연결
        containerView.addGestureRecognizer(tapGesture)
        contentView.addGestureRecognizer(tapGesture)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let strokeColor = UIColor(red: 120/255, green: 130/255, blue: 255/255, alpha: 0.7)
        dashedBorderLayer.strokeColor = strokeColor.cgColor
        dashedBorderLayer.fillColor = nil
        dashedBorderLayer.lineDashPattern = [5, 3]
        dashedBorderLayer.lineWidth = 1.2
        dashedBorderLayer.path = UIBezierPath(roundedRect: containerView.bounds, cornerRadius: 14).cgPath
    }
}
