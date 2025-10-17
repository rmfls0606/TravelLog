//
//  MemorySummaryCard.swift
//  TravelLog
//
//  Created by 이상민 on 10/17/25.
//

import UIKit
import RealmSwift
import SnapKit

final class MemorySummaryCard: BaseView {
    
    // MARK: - UI
    private let iconContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = UIColor.white
        view.image = UIImage(systemName: "rectangle.and.pencil.and.ellipsis")
        return view
    }()
    
    private let titleView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 16, weight: .heavy)
        view.textColor = .systemGray
        view.text = "현재까지 기록된 추억"
        return view
    }()
    
    private let subtitleLabel: UILabel = {
        let view = UILabel()
        view.font = .systemFont(ofSize: 14)
        view.textColor = .label
        return view
    }()
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        titleView.addSubview(titleLabel)
        titleView.addSubview(subtitleLabel)
        addSubviews(iconContainer, titleView)
        iconContainer.addSubview(iconView)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        iconContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(36)
        }
        
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(18)
        }
        
        titleView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(iconContainer.snp.trailing).offset(16)
            make.trailing.equalToSuperview().inset(16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
            make.top.equalToSuperview()
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Style
    override func configureView() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    // MARK: - Public Configure
    func update(with summary: MemorySummary) {
            subtitleLabel.text = "\(summary.journalCount)개의 소중한 순간들"
            applyColorTheme(summary.status.color)
        }
    
    // MARK: - Theme Setter
    private func applyColorTheme(_ color: UIColor) {
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self else { return }
            self.backgroundColor = color.withAlphaComponent(0.1)
            self.layer.borderColor = color.withAlphaComponent(0.15).cgColor
            self.iconContainer.backgroundColor = color.withAlphaComponent(0.85)
            self.iconContainer.layer.borderColor = color.withAlphaComponent(0.85).cgColor
            self.titleLabel.textColor = color.darker()
            self.subtitleLabel.textColor = color
        }
    }
}

// MARK: - UIColor Helper
private extension UIColor {
    func darker(by percentage: CGFloat = 0.15) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(r - percentage, 0),
                       green: max(g - percentage, 0),
                       blue: max(b - percentage, 0),
                       alpha: a)
    }
}
