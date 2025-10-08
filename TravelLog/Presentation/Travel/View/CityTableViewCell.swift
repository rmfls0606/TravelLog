//
//  CityTableViewCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import UIKit
import SnapKit

final class CityTableViewCell: UITableViewCell {
    private let cityLabel = UILabel()
    private let regionLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        cityLabel.font = .boldSystemFont(ofSize: 16)
        regionLabel.font = .systemFont(ofSize: 14)
        regionLabel.textColor = .gray
        
        let stack = UIStackView(arrangedSubviews: [cityLabel, regionLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
    }
    
    func configure(with city: City) {
        var formattedCity = city.name
        
        if formattedCity.hasSuffix("특별자치도") {
            formattedCity = String(formattedCity.dropLast(5))
        } else if formattedCity.hasSuffix("특별자치시") {
            formattedCity = String(formattedCity.dropLast(5))
        } else if formattedCity.hasSuffix("특별시") {
            formattedCity = String(formattedCity.dropLast(3))
        } else if formattedCity.hasSuffix("광역시") {
            formattedCity = String(formattedCity.dropLast(3))
        } else if formattedCity.hasSuffix("시") {
            formattedCity = String(formattedCity.dropLast(1))
        } else if formattedCity.hasSuffix("군") {
            formattedCity = String(formattedCity.dropLast(1))
        }
        
        cityLabel.text = formattedCity
        regionLabel.text = "\(city.region)"
    }
}
