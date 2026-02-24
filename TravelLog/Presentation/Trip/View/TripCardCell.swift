//
//  TripCardCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import RealmSwift
import Kingfisher

// MARK: - TripCardCell
final class TripCardCell: BaseTableViewCell {
    
    // MARK: - Components
    private let cardView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        view.layer.borderWidth = 1
        view.backgroundColor = .white
        view.clipsToBounds = true
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 2
        return view
    }()
    
    private let cityImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.image = .seoul
        view.clipsToBounds = true
        return view
    }()
    
    private let overlayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        return view
    }()
    
    private let durationBadge: PaddedLabel = {
        let view = PaddedLabel()
        view.font = .systemFont(ofSize: 13, weight: .semibold)
        view.textColor = .black
        view.backgroundColor = .white
        view.clipsToBounds = true
        view.textInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return view
    }()
    
    private let statusBadge: PaddedLabel = {
        let view = PaddedLabel()
        view.font = .systemFont(ofSize: 13, weight: .bold)
        view.textColor = .white
        view.clipsToBounds = true
        view.textInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        return view
    }()
    
    private let cityLabel: UILabel = {
        let view = UILabel()
        view.font = .boldSystemFont(ofSize: 22)
        view.textColor = .white
        return view
    }()
    
    private let countryLabel: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 15, weight: .medium)
        view.textColor = .white.withAlphaComponent(0.9)
        return view
    }()
    
    private let floatingTransportContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 22
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemBlue.cgColor
        return view
    }()
    
    private let floatingTransportIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    // MARK: - Route Section
    private let routeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let departureStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 4
        return view
    }()
    
    private let destinationStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 4
        return view
    }()
    
    private let lineLeft: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray4
        return view
    }()
    
    private let lineRight: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray4
        return view
    }()
    
    private let transportContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor.systemBlue.cgColor
        return view
    }()
    
    private let routeTransportIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let departureCityLabel: UILabel = {
        let view = UILabel()
        view.font = .boldSystemFont(ofSize: 16)
        view.textColor = .black
        return view
    }()
    
    private let departureTagLabel: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 12)
        view.textColor = .gray
        view.text = "출발"
        return view
    }()
    
    private let destinationCityLabel: UILabel = {
        let view = UILabel()
        view.font = .boldSystemFont(ofSize: 16)
        view.textColor = .black
        return view
    }()
    
    private let destinationTagLabel: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 12)
        view.textColor = .gray
        view.text = "도착"
        return view
    }()
    
    // MARK: - Date Section
    private let dateContainer: UIView = {
        let view = UIView()
        return view
    }()
    
    private let dateIconBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 18
        return view
    }()
    
    private let dateIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemBlue
        view.image = UIImage(systemName: "calendar")
        return view
    }()
    
    private let dateLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 2
        view.font = .systemFont(ofSize: 14)
        view.textColor = .darkGray
        return view
    }()
    
    // MARK: - New Memory Summary Card
    private let memorySummaryCard = MemorySummaryCard()
    
    private(set) var continueButton: UIButton = {
        var config = UIButton.Configuration.filled()
        var imageConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.background.cornerRadius = 16
        config.baseBackgroundColor = .systemGreen
        config.baseForegroundColor = .white
        config.preferredSymbolConfigurationForImage = imageConfig
        config.image = UIImage(systemName: "map")
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .boldSystemFont(ofSize: 16)
            return out
        }
        
        let button = UIButton(configuration: config)
        
        return button
    }()
    
    var disposeBag = DisposeBag()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cityImageView.kf.cancelDownloadTask()
        cityImageView.image = .seoul
        disposeBag = DisposeBag()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        durationBadge.layoutIfNeeded()
        statusBadge.layoutIfNeeded()
        durationBadge.layer.cornerRadius = durationBadge.frame.height / 2
        statusBadge.layer.cornerRadius = statusBadge.frame.height / 2
    }
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        contentView.addSubview(cardView)
        cardView.addSubviews(
            cityImageView, overlayView,
            durationBadge, statusBadge,
            cityLabel, countryLabel,
            floatingTransportContainer,
            routeContainer,
            dateContainer, memorySummaryCard, continueButton
        )
        floatingTransportContainer.addSubview(floatingTransportIcon)
        
        routeContainer.addSubviews(departureStack, destinationStack, lineLeft, lineRight, transportContainer)
        transportContainer.addSubview(routeTransportIcon)
        departureStack.addArrangedSubview(departureCityLabel)
        departureStack.addArrangedSubview(departureTagLabel)
        destinationStack.addArrangedSubview(destinationCityLabel)
        destinationStack.addArrangedSubview(destinationTagLabel)
        
        dateContainer.addSubviews(dateIconBackground, dateLabel)
        dateIconBackground.addSubview(dateIcon)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        cityImageView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview()
            make.height.equalTo(cardView.snp.width).multipliedBy(0.6)
        }
        overlayView.snp.makeConstraints { make in
            make.edges.equalTo(cityImageView)
        }
        
        durationBadge.snp.makeConstraints { make in
            make.top.leading.equalTo(cityImageView).inset(16)
        }
        statusBadge.snp.makeConstraints { make in
            make.top.trailing.equalTo(cityImageView).inset(16)
        }
        
        cityLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(cityImageView.snp.bottom).inset(40)
        }
        countryLabel.snp.makeConstraints { make in
            make.leading.equalTo(cityLabel)
            make.top.equalTo(cityLabel.snp.bottom).offset(4)
        }
        
        floatingTransportContainer.snp.makeConstraints { make in
            make.size.equalTo(44)
            make.trailing.equalTo(cityImageView).inset(16)
            make.bottom.equalTo(cityImageView).inset(16)
        }
        floatingTransportIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        
        routeContainer.snp.makeConstraints { make in
            make.top.equalTo(cityImageView.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(80)
        }
        departureStack.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
        }
        destinationStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20)
            make.centerY.equalToSuperview()
        }
        transportContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(36)
        }
        routeTransportIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }
        lineLeft.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.centerY.equalToSuperview()
            make.leading.equalTo(departureStack.snp.trailing).offset(16)
            make.trailing.equalTo(transportContainer.snp.leading).offset(-16)
        }
        lineRight.snp.makeConstraints { make in
            make.height.equalTo(2)
            make.centerY.equalToSuperview()
            make.leading.equalTo(transportContainer.snp.trailing).offset(16)
            make.trailing.equalTo(destinationStack.snp.leading).offset(-16)
        }
        
        dateContainer.snp.makeConstraints { make in
            make.top.equalTo(routeContainer.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        dateIconBackground.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.size.equalTo(36)
        }
        dateIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }
        dateLabel.snp.makeConstraints { make in
            make.leading.equalTo(dateIconBackground.snp.trailing).offset(16)
            make.centerY.equalTo(dateIconBackground)
        }
        
        memorySummaryCard.snp.makeConstraints { make in
            make.top.equalTo(dateContainer.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.height.equalTo(80)
        }
        
        continueButton.snp.makeConstraints { make in
            make.top.equalTo(memorySummaryCard.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            //            make.height.equalTo(48)
            make.bottom.equalToSuperview().inset(16)
        }
    }
    
    override func configureView() {
        contentView.backgroundColor = .systemGroupedBackground
        selectionStyle = .none
    }
    
    // MARK: - Configure
    func configure(with trip: TravelTable, journalCount: Int) {
        cityImageView.kf.cancelDownloadTask()

        if let localFilename = trip.destination?.localImageFilename,
           let localURL = cityImageFileURL(filename: localFilename),
           FileManager.default.fileExists(atPath: localURL.path),
           let localImage = UIImage(contentsOfFile: localURL.path) {
            cityImageView.image = localImage
        } else if let imageUrl = trip.destination?.imageURL,
                  let url = URL(string: imageUrl) {
            cityImageView.kf.setImage(with: url)
        } else {
            cityImageView.image = .seoul
        }
        
        cityLabel.text = trip.destination?.name
        countryLabel.text = trip.destination?.country
        departureCityLabel.text = trip.departure?.name ?? "-"
        destinationCityLabel.text = trip.destination?.name ?? "-"
        
        let iconName = Transport(rawValue: trip.transport)?.iconName ?? "airplane"
        floatingTransportIcon.image = UIImage(systemName: iconName)
        routeTransportIcon.image = UIImage(systemName: iconName)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        dateLabel.text = "\(formatter.string(from: trip.startDate))\n~ \(formatter.string(from: trip.endDate))"
        
        durationBadge.text = calculateDuration(start: trip.startDate, end: trip.endDate)
        
        let status = determineState(trip: trip)
        updateStatusBadge(status)
        
        let summary = MemorySummary(journalCount: journalCount, status: status)
        memorySummaryCard.update(with: summary)
    }
    
    private func calculateDuration(start: Date, end: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return "\(days)박 \(days + 1)일"
    }
    
    private func updateStatusBadge(_ status: TripStatus) {
        switch status {
        case .planned:
            statusBadge.text = "계획중"
            statusBadge.backgroundColor = status.color
            cardView.layer.borderColor = status.color.cgColor
            applyButtonConfiguration(
                title: "여행 계속하기",
                iconName: "map",
                color: status.color
            )
            
        case .ongoing:
            statusBadge.text = "여행중"
            statusBadge.backgroundColor = status.color
            cardView.layer.borderColor = status.color.cgColor
            applyButtonConfiguration(
                title: "여행 계속하기",
                iconName: "map",
                color: status.color
            )
            
        case .completed:
            statusBadge.text = "완료"
            statusBadge.backgroundColor = status.color
            cardView.layer.borderColor = UIColor.systemGray5.cgColor
            applyButtonConfiguration(
                title: "추억 다시보기",
                iconName: "heart",
                color: status.color,
                border: true
            )
        }
    }
    
    private func applyButtonConfiguration(
        title: String,
        iconName: String,
        color: UIColor,
        border: Bool = false
    ) {
        var config = continueButton.configuration
        config?.baseBackgroundColor = color
        config?.image = UIImage(systemName: iconName)
        config?.title = title
        
        config?.background.strokeWidth = 1
        config?.background.strokeColor = UIColor.clear
        
        continueButton.configuration = config
    }
    
    private func determineState(trip: TravelTable) -> TripStatus {
        let today = Date()
        if today < trip.startDate {
            return .planned
        } else if today >= trip.startDate && today <= trip.endDate {
            return .ongoing
        } else {
            return .completed
        }
    }

    private func cityImageFileURL(filename: String) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents
            .appendingPathComponent("CityImages", isDirectory: true)
            .appendingPathComponent(filename)
    }
}

// MARK: - Padding Label
final class PaddedLabel: UILabel {
    var textInsets: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(
            width: s.width + textInsets.left + textInsets.right,
            height: s.height + textInsets.top + textInsets.bottom
        )
    }
}
