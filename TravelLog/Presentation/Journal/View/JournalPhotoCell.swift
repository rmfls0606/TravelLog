//
//  JournalPhotoCell.swift
//  TravelLog
//
//  Created by 이상민 on 11/10/25.
//

import UIKit
import SnapKit

final class JournalPhotoCell: UITableViewCell {

    private var timelineTopConstraint: Constraint?
    private var dotTopConstraint: Constraint?

    private let timelineLine = UIView()
    private let dotView = UIView()

    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()

    private let photosContainer = UIView()
    private let collectionView: UICollectionView
    private var collectionHeightConstraint: Constraint?

    // footerStack (버튼 + 설명)
    private let footerStack = UIStackView()
    private let moreButton = UIButton(type: .system)
    private let descriptionLabel = UILabel()

    private var images: [UIImage] = []
    private var isExpanded = false
    private let maxPreviewCount = 3
    var onHeightChange: (() -> Void)?

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setupViews()
        setupLayout()
        setupAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        isExpanded = false
        images.removeAll()
        descriptionLabel.text = nil
        descriptionLabel.isHidden = false
        moreButton.isHidden = true
    }

    // MARK: - Public
    func configure(with block: JournalBlockTable) {
        timeLabel.text = formatKoreanTime(block.createdAt)
        locationLabel.text = block.placeName ?? "위치 없음"

        // 설명 존재 여부
        if let desc = block.photoDescription,
           !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            descriptionLabel.isHidden = false
            descriptionLabel.text = desc
        } else {
            descriptionLabel.isHidden = true
            descriptionLabel.text = nil
        }

        // 이미지 로드
        let filenames = Array(block.imageURLs)
        images = filenames.compactMap { LinkMetadataRepositoryImpl.loadImageFromDocuments(filename: $0) }

        moreButton.isHidden = images.count <= maxPreviewCount
        updateMoreButtonTitle()

        contentView.layoutIfNeeded()
        updateCollectionHeight()
        collectionView.reloadData()
    }

    func setIsFirstInTimeline(_ isFirst: Bool) {
        timelineTopConstraint?.update(offset: isFirst ? 16 : 0)
        dotTopConstraint?.update(offset: isFirst ? 36 : 36)
    }
}

// MARK: - Setup
private extension JournalPhotoCell {
    func setupViews() {
        timelineLine.backgroundColor = .systemGray5
        dotView.backgroundColor = .systemPink
        dotView.layer.cornerRadius = 7

        contentView.addSubview(timelineLine)
        contentView.addSubview(dotView)
        contentView.addSubview(cardView)

        cardView.addSubview(timeLabel)
        cardView.addSubview(locationLabel)
        cardView.addSubview(photosContainer)

        footerStack.axis = .vertical
        footerStack.spacing = 8
        footerStack.alignment = .leading    // 왼쪽 정렬
        footerStack.addArrangedSubview(moreButton)
        footerStack.addArrangedSubview(descriptionLabel)
        cardView.addSubview(footerStack)

        photosContainer.addSubview(collectionView)

        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoItemCell.self,
                                forCellWithReuseIdentifier: PhotoItemCell.identifier)

        moreButton.addTarget(self, action: #selector(didTapMore), for: .touchUpInside)
    }

    func setupLayout() {
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
            // bottom 제약은 낮은 priority로 설정
            $0.bottom.equalToSuperview().inset(8).priority(.low)
        }

        timeLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(16)
        }

        locationLabel.snp.makeConstraints {
            $0.centerY.equalTo(timeLabel)
            $0.trailing.equalToSuperview().inset(16)
        }

        photosContainer.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }

        collectionView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            collectionHeightConstraint = $0.height.equalTo(0).constraint
        }

        footerStack.snp.makeConstraints {
            $0.top.equalTo(collectionView.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(16)
        }
    }

    func setupAppearance() {
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowRadius = 3
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)

        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray

        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .darkGray

        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .darkText
        descriptionLabel.numberOfLines = 0

        moreButton.setTitleColor(.systemGray, for: .normal)
        moreButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
    }
}

// MARK: - Actions
private extension JournalPhotoCell {
    @objc func didTapMore() {
        isExpanded.toggle()
        updateMoreButtonTitle()
        updateCollectionHeight()

        UIView.performWithoutAnimation {
            collectionView.reloadData()
            collectionView.layoutIfNeeded()
        }

        DispatchQueue.main.async { [weak self] in
            self?.onHeightChange?()
        }
    }

    func updateMoreButtonTitle() {
        let hiddenCount = max(images.count - maxPreviewCount, 0)
        moreButton.setTitle(hiddenCount <= 0 ? "" : (isExpanded ? "접기" : "+\(hiddenCount)장 더보기"), for: .normal)
    }

    func updateCollectionHeight() {
        let visibleCount = isExpanded ? images.count : min(images.count, maxPreviewCount)
        guard visibleCount > 0 else {
            collectionHeightConstraint?.update(offset: 0)
            return
        }

        layoutIfNeeded()
        let width = collectionView.bounds.width
        let spacing: CGFloat = 8
        let itemWidth = (width - (2 * spacing)) / 3
        let rows = ceil(CGFloat(visibleCount) / 3.0)
        let height = rows * itemWidth + max(0, rows - 1) * spacing
        collectionHeightConstraint?.update(offset: height)
    }

    func formatKoreanTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a hh:mm"
        return f.string(from: date)
    }
}

// MARK: - CollectionView
extension JournalPhotoCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        isExpanded ? images.count : min(images.count, maxPreviewCount)
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoItemCell.identifier,
            for: indexPath
        ) as! PhotoItemCell
        cell.configure(with: images[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let spacing: CGFloat = 8
        let width = collectionView.bounds.width
        let itemWidth = (width - (spacing * 2)) / 3
        return CGSize(width: itemWidth, height: itemWidth)
    }
}
