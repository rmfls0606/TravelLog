//
//  JournalDateHeaderView.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit

final class JournalDateHeaderView: UITableViewHeaderFooterView {
    
    static let identifier = "JournalDateHeaderView"
    
    private let containerView = UIView()
    private let dateLabel = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.backgroundColor = .clear
        
        // 작은 카드 스타일
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.systemGray5.cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.08
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 2
        containerView.clipsToBounds = false
        
        // 날짜 라벨
        dateLabel.font = .systemFont(ofSize: 16, weight: .bold)
        dateLabel.textColor = .darkGray
        dateLabel.textAlignment = .center
        
        contentView.addSubview(containerView)
        containerView.addSubview(dateLabel)
        
        // 카드가 label 크기에 맞게 감싸지도록
        containerView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16)
            $0.top.bottom.equalToSuperview().inset(16)
        }
        
        dateLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }
    }
    
    func configure(date: Date) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        dateLabel.text = formatter.string(from: date)
    }
}
