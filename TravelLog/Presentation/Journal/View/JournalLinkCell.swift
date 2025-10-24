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

final class JournalLinkCell: UITableViewCell {
    
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()
    private let blockView = UIView()
    
    private let thumbnailImageView = UIImageView()
    private let linkView = UIView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let linkButton = UIButton(type: .system)
    
    private var timelineTopConstraint: Constraint?
    private var dotTopConstraint: Constraint?
    
    let disposeBag = DisposeBag()
    private let linkTapGesture = UITapGestureRecognizer()
    private var currentBlock: JournalBlockTable?
    
    // 외부로 링크 탭 이벤트 전달
    let linkTapped = PublishRelay<String>()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupGesture()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        titleLabel.text = nil
        descLabel.text = nil
        currentBlock = nil
    }
    
    private func setupView() {
        selectionStyle = .none
        backgroundColor = .clear
        
        timelineLine.backgroundColor = UIColor.systemGray5
        dotView.backgroundColor = UIColor.systemGreen
        dotView.layer.cornerRadius = 7
        
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 3
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        blockView.layer.cornerRadius = 12
        blockView.clipsToBounds = true
        blockView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .darkGray
        
        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.numberOfLines = 2
        descLabel.font = .systemFont(ofSize: 12)
        descLabel.textColor = .darkGray
        descLabel.numberOfLines = 4
        
        var config = UIButton.Configuration.plain()
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        config.baseForegroundColor = .systemGreen
        config.preferredSymbolConfigurationForImage = imageConfig
        config.image = UIImage(systemName: "arrow.up.right")
        config.imagePlacement = .trailing
        config.imagePadding = 6
        var titleAttr = AttributedString("링크 보기")
        titleAttr.font = .systemFont(ofSize: 12, weight: .bold)
        config.attributedTitle = titleAttr
        linkButton.configuration = config
        
        thumbnailImageView.layer.cornerRadius = 10
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.backgroundColor = UIColor.systemGray6
        
        contentView.addSubviews(timelineLine, dotView, cardView)
        cardView.addSubviews(timeLabel, locationLabel, blockView)
        blockView.addSubviews(linkView, linkButton)
        linkView.addSubviews(thumbnailImageView, titleLabel, descLabel)
        
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
        linkView.snp.makeConstraints {
            $0.top.horizontalEdges.equalToSuperview().inset(12)
        }
        thumbnailImageView.snp.makeConstraints {
            $0.top.leading.equalToSuperview()
            $0.bottom.lessThanOrEqualToSuperview().inset(12)
            $0.width.height.equalTo(70)
        }
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalTo(thumbnailImageView.snp.trailing).offset(16)
            $0.trailing.equalToSuperview()
        }
        descLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(8)
            $0.leading.equalTo(thumbnailImageView.snp.trailing).offset(16)
            $0.trailing.equalToSuperview()
            $0.bottom.lessThanOrEqualToSuperview().inset(12)
        }
        linkButton.snp.makeConstraints {
            $0.top.equalTo(linkView.snp.bottom)
            $0.horizontalEdges.equalToSuperview().offset(12)
            $0.bottom.equalToSuperview().inset(12)
        }
    }
    
    private func setupGesture() {
        linkView.isUserInteractionEnabled = true
        linkView.addGestureRecognizer(linkTapGesture)
        
        linkTapGesture.rx.event
            .bind(with: self) { owner, _ in
                guard let url = owner.currentBlock?.linkURL else { return }
                owner.linkTapped.accept(url)
            }
            .disposed(by: disposeBag)
        
        linkTapGesture.rx.event
            .bind(with: self) { owner, _ in
                guard let urlString = owner.currentBlock?.linkURL,
                      let url = URLNormalizer.normalized(urlString)
                else { return }
                owner.linkTapped.accept(url.absoluteString)
            }
            .disposed(by: disposeBag)
    }
    
    func configure(with block: JournalBlockTable) {
        currentBlock = block
        timeLabel.text = formatKoreanTime(block.createdAt)
        locationLabel.text = block.placeName ?? "위치 없음"
        titleLabel.text = block.linkTitle ?? "링크 미리보기"
        descLabel.text = block.linkDescription ?? block.linkURL
        
        if let filename = block.linkImagePath,
           let image = LinkMetadataRepositoryImpl.loadImageFromDocuments(filename: filename) {
            thumbnailImageView.image = image
        } else {
            thumbnailImageView.image = UIImage(systemName: "globe")
        }
    }
    
    func setIsFirstInTimeline(_ isFirst: Bool) {
        timelineTopConstraint?.update(offset: isFirst ? 16 : 0)
        dotTopConstraint?.update(offset: 36)
    }
    
    private func formatKoreanTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        return formatter.string(from: date)
    }
}
