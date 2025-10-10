//
//  JournalTextCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit

final class JournalTextCell: UITableViewCell {
    
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()
    private let blockView = UIView() // 색상 카드
    private let contentLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // 수직 라인
        timelineLine.backgroundColor = UIColor.systemGray5
        
        // 점(circle)
        dotView.backgroundColor = UIColor.systemBlue
        dotView.layer.cornerRadius = 5
        
        // 흰색 카드뷰 (외곽)
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 3
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        // 안쪽 블록뷰 (텍스트 카드)
        blockView.layer.cornerRadius = 12
        blockView.clipsToBounds = true
        blockView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.9)
        
        // 라벨
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray
        
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .darkGray
        
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.textColor = .white
        contentLabel.numberOfLines = 0
        
        // 계층
        contentView.addSubviews(timelineLine, dotView, cardView)
        cardView.addSubviews(timeLabel, locationLabel, blockView)
        blockView.addSubview(contentLabel)
        
        // 제약
        timelineLine.snp.makeConstraints {
            $0.width.equalTo(2)
            $0.top.bottom.equalToSuperview()
            $0.leading.equalToSuperview().inset(24)
        }
        
        dotView.snp.makeConstraints {
            $0.centerX.equalTo(timelineLine)
            $0.top.equalToSuperview().inset(20)
            $0.size.equalTo(10)
        }
        
        cardView.snp.makeConstraints {
            $0.leading.equalTo(timelineLine.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(16)
        }
        
        timeLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(16)
        }
        
        locationLabel.snp.makeConstraints {
            $0.centerY.equalTo(timeLabel)
            $0.trailing.equalToSuperview().inset(16)
        }
        
        blockView.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(16)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        
        contentLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(12)
        }
    }
    
    func configure(with block: JournalBlockTable) {
        timeLabel.text = formatKoreanTime(block.createdAt)
        locationLabel.text = block.placeName ?? "위치 없음"
        contentLabel.text = block.text ?? "(내용 없음)"
        
        // ✅ 분홍색 계열 고정
        blockView.backgroundColor = UIColor(
            red: 255/255,
            green: 120/255,
            blue: 150/255,
            alpha: 0.92
        )
    }
    
    private func formatKoreanTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm" // 오전 04:21
        return formatter.string(from: date)
    }
}
