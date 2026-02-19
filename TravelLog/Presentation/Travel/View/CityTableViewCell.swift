//
//  CityTableViewCell.swift
//  TravelLog
//
//  Created by 이상민 on 10/8/25.
//

import UIKit
import SnapKit
import Kingfisher

final class CityTableViewCell: BaseTableViewCell {
    
    // MARK: - UI
    private let cityContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private let cityThumbnailView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = 12
        view.backgroundColor = .lightGray
        view.clipsToBounds = true
        return view
    }()
    
    private let cityLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()
    
    private let countryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gray
        return label
    }()
    
    private let chevronIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "chevron.right"))
        view.tintColor = .systemGray3
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = 4
        return view
    }()
    
    // MARK: - Lifecycle
    override func configureHierarchy() {
        stackView.addArrangedSubview(cityLabel)
        stackView.addArrangedSubview(countryLabel)
        cityContentView.addSubview(cityThumbnailView)
        cityContentView.addSubview(stackView)
        cityContentView.addSubview(chevronIcon)
        
        contentView.addSubview(cityContentView)
    }
    
    override func configureLayout() {
        cityContentView.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(16)
            make.verticalEdges.equalToSuperview().inset(6)
        }
        
        cityThumbnailView.snp.makeConstraints { make in
            make.leading.verticalEdges.equalToSuperview().inset(16)
            make.width.equalTo(cityThumbnailView.snp.height)
        }
        
        stackView.snp.makeConstraints {
            $0.leading.equalTo(cityThumbnailView.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
        }
        chevronIcon.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(14)
        }
    }
    
    override func configureView() {
        backgroundColor = .systemGray6
        selectionStyle = .none
    }
    
    // MARK: - Configure
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
        countryLabel.text = "\(city.country)"
    
        if let imageUrl = city.imageUrl,
           let url = URL(string: imageUrl){
            cityThumbnailView.kf.setImage(with: url)
        }
    }
}
