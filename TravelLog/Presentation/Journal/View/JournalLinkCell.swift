//
//  JournalLinkCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/22/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class JournalLinkCell: BaseTableViewCell {

    private var timelineTopConstraint: Constraint?
    private var dotTopConstraint: Constraint?
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()
    private let blockView = UIView() // 색상 카드
    private let urlLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setIsFirstInTimeline(false)
    }

    override func configureHierarchy() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubviews(timelineLine, dotView, cardView)
        cardView.addSubviews(timeLabel, locationLabel, blockView)
        blockView.addSubview(urlLabel)
    }

    override func configureLayout() {
        timelineLine.snp.makeConstraints {
            $0.width.equalTo(2)
            $0.leading.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview()
            timelineTopConstraint = $0.top.equalToSuperview().constraint
        }

        dotView.snp.makeConstraints {
            $0.centerX.equalTo(timelineLine)
            dotTopConstraint = $0.top.equalToSuperview().inset(20).constraint
            $0.size.equalTo(14)
        }

        cardView.snp.makeConstraints {
            $0.leading.equalTo(timelineLine.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(8)
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

        urlLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(12)
        }
    }

    override func configureView() {
        // 수직 라인
        timelineLine.backgroundColor = UIColor.systemGray5

        // 점(circle)
        dotView.backgroundColor = UIColor.systemPurple
        dotView.layer.cornerRadius = 7

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

        // 라벨
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray

        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .darkGray

        urlLabel.font = .systemFont(ofSize: 14)
        urlLabel.textColor = .white
        urlLabel.numberOfLines = 0
    }

    func configure(with block: JournalBlockTable) {
        timeLabel.text = formatKoreanTime(block.createdAt)
        locationLabel.text = block.placeName ?? "위치 없음"
        urlLabel.text = block.linkURL ?? "(내용 없음)"

        // 링크 블록은 보라색 계열
        blockView.backgroundColor = UIColor(
            red: 180/255,
            green: 100/255,
            blue: 255/255,
            alpha: 1.0
        )
    }

    private func formatKoreanTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm" // 오전 04:21
        return formatter.string(from: date)
    }

    func setIsFirstInTimeline(_ isFirst: Bool) {
        // 라인은 첫 셀만 16 내려서 시작 (아닌 경우 0으로 붙임)
        timelineTopConstraint?.update(offset: isFirst ? 16 : 0)
        // 점은 라인보다 살짝 내려오게(시각적으로 20이 보기 좋음)
        dotTopConstraint?.update(offset: isFirst ? 36 : 36)
        // 필요하면 즉시 레이아웃
        setNeedsLayout()
        layoutIfNeeded()
    }
}
