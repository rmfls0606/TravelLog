//
//  CustomCaledarCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/3/25.
//

import UIKit
import FSCalendar
import SnapKit

// MARK: - Custom Calendar Cell
final class CustomCalendarCell: FSCalendarCell {
    
    private let bgView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()
    
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private let dotView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 3
        view.isHidden = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureLayout()
    }
    
    required init?(coder aDecoder: NSCoder!) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureHierarchy(){
        contentView.addSubview(bgView)
        
        contentView.addSubview(dayLabel)
        
        contentView.addSubview(dotView)
    }
    
    private func configureLayout(){
        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        
        dayLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dotView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(dayLabel.snp.bottom).offset(3)
            make.size.equalTo(6)
        }
    }
    
    func configure(date: Date,
                   isToday: Bool,
                   isStart: Bool,
                   isEnd: Bool,
                   inRange: Bool,
                   isWeekend: Bool) {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        dayLabel.text = formatter.string(from: date)
        
        bgView.backgroundColor = .clear
        bgView.layer.borderWidth = 0
        bgView.layer.borderColor = nil
        dayLabel.textColor = .black
        dotView.isHidden = true
        
        if isStart || isEnd {
            bgView.backgroundColor = .systemBlue
            dayLabel.textColor = .white
        } else if inRange {
            bgView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            dayLabel.textColor = .systemBlue
        } else if isToday {
            bgView.layer.borderWidth = 1.5
            bgView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
            bgView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
            dayLabel.textColor = .systemBlue
            dotView.isHidden = false
        } else if isWeekend {
            dayLabel.textColor = .red
        }
    }
}
