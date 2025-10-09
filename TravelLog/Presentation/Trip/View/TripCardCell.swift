//
//  TripCardCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit

final class TripTextCell: UITableViewCell {
    
    private let cardView = UIView()
    
    private let cityLabel = UILabel()
    private let countryLabel = UILabel()
    private let statusBadgeBox = UIView()
    private let statusBadge = UILabel()
    private let durationLabel = UILabel()
    
    private let routeView = UIView()
    private let departureLabel = UILabel()
    private let transportIcon = UIImageView()
    private let destinationLabel = UILabel()
    
    private let dateIcon = UIImageView()
    private let dateLabel = UILabel()
    
    private let continueButton = UIButton()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureHierarchy()
        configureLayout()
        configureStyle()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}

extension TripTextCell {
    func configureHierarchy() {
        statusBadgeBox.addSubview(statusBadge)
        contentView.addSubview(cardView)
        cardView.addSubviews(cityLabel, countryLabel, statusBadgeBox, durationLabel,
                             routeView, dateIcon, dateLabel, continueButton)
        routeView.addSubviews(departureLabel, transportIcon, destinationLabel)
    }
    
    func configureLayout() {
        cardView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
        }
        
        cityLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(20)
            $0.leading.equalToSuperview().offset(20)
        }
        
        countryLabel.snp.makeConstraints {
            $0.leading.equalTo(cityLabel)
            $0.top.equalTo(cityLabel.snp.bottom).offset(4)
        }
        
        statusBadgeBox.snp.makeConstraints {
            $0.verticalEdges.equalTo(cityLabel)
            $0.trailing.equalToSuperview().inset(16)
        }
        
        statusBadge.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(4)
        }
        
        durationLabel.snp.makeConstraints {
            $0.top.equalTo(statusBadge.snp.bottom).offset(8)
            $0.trailing.equalTo(statusBadge)
        }
        
        routeView.snp.makeConstraints {
            $0.top.equalTo(countryLabel.snp.bottom).offset(16)
            $0.horizontalEdges.equalToSuperview().inset(16)
            $0.height.equalTo(44)
        }
        
        departureLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
        }
        
        transportIcon.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(20)
        }
        
        destinationLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(12)
            $0.centerY.equalToSuperview()
        }
        
        dateIcon.snp.makeConstraints {
            $0.top.equalTo(routeView.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(20)
            $0.size.equalTo(20)
        }
        
        dateLabel.snp.makeConstraints {
            $0.leading.equalTo(dateIcon.snp.trailing).offset(8)
            $0.centerY.equalTo(dateIcon)
        }
        
        continueButton.snp.makeConstraints {
            $0.top.equalTo(dateLabel.snp.bottom).offset(20)
            $0.horizontalEdges.equalToSuperview().inset(16)
            $0.height.equalTo(48)
            $0.bottom.equalToSuperview().inset(16)
        }
    }
    
    func configureStyle() {
        backgroundColor = .clear
        selectionStyle = .none
        
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowRadius = 8
        
        cityLabel.font = .boldSystemFont(ofSize: 20)
        cityLabel.textColor = .black
        countryLabel.font = .systemFont(ofSize: 14)
        countryLabel.textColor = .darkGray
        
        statusBadge.font = .boldSystemFont(ofSize: 12)
        statusBadge.textColor = .white
        statusBadgeBox.layer.cornerRadius = 10
        statusBadgeBox.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        durationLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        durationLabel.textColor = .systemGray
        
        routeView.backgroundColor = UIColor.systemGray6
        routeView.layer.cornerRadius = 12
        departureLabel.font = .systemFont(ofSize: 14, weight: .medium)
        destinationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        transportIcon.tintColor = .systemBlue
     
        
        dateIcon.tintColor = .systemBlue
        dateIcon.image = UIImage(systemName: "calendar")
        dateLabel.font = .systemFont(ofSize: 14, weight: .medium)
        
        
        continueButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        continueButton.setTitleColor(.white, for: .normal)
 
        continueButton.layer.cornerRadius = 14
    }
    
    func configure(with trip: TravelTable) {
        cityLabel.text = trip.destination?.name ?? "-"
        countryLabel.text = trip.destination?.country ?? "-"
        
        departureLabel.text = trip.departure?.name ?? "-"
        destinationLabel.text = trip.destination?.name ?? "-"
        transportIcon.image = UIImage(systemName: Transport(rawValue: trip.transport)!.iconName)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        dateLabel.text = "\(formatter.string(from: trip.startDate)) ~ \(formatter.string(from: trip.endDate))"
        
        durationLabel.text = calculateDuration(start: trip.startDate, end: trip.endDate)
        
        let now = Date()
        if trip.startDate > now {
            statusBadge.text = "계획중"
            statusBadgeBox.backgroundColor = .systemBlue
            continueButton.backgroundColor = UIColor.systemBlue
            statusBadgeBox.layer.opacity = 1.0
            continueButton.layer.opacity = 1.0
            continueButton.setTitle("여행 계속하기", for: .normal)
        } else if trip.endDate < now {
            statusBadge.text = "완료"
            statusBadgeBox.backgroundColor = .systemPink
            statusBadgeBox.layer.opacity = 0.5
            continueButton.backgroundColor = UIColor.systemPink
            continueButton.layer.opacity = 0.5
            continueButton.setTitle("추억 다시보기", for: .normal)
        } else {
            statusBadge.text = "여행중"
            statusBadgeBox.backgroundColor = .systemGreen
            continueButton.backgroundColor = UIColor.systemGreen
            statusBadgeBox.layer.opacity = 1.0
            continueButton.layer.opacity = 1.0
            continueButton.setTitle("여행 계속하기", for: .normal)
        }
    }
    
    private func calculateDuration(start: Date, end: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return "\(days)박 \(days + 1)일"
    }
}
