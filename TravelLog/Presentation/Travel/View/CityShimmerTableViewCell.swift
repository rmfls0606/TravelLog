//
//  CityShimmerTableViewCell.swift
//  TravelLog
//
//  Created by 이상민 on 2/22/26.
//

import UIKit
import SnapKit

final class CityShimmerTableViewCell: BaseTableViewCell {
    private let cityContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()

    private let thumbnailShimmer: ShimmerView = {
        let view = ShimmerView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()

    private let titleShimmer: ShimmerView = {
        let view = ShimmerView()
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private let subtitleShimmer: ShimmerView = {
        let view = ShimmerView()
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        return view
    }()

    private let chevronPlaceholder: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray4
        view.layer.cornerRadius = 2
        return view
    }()

    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = 6
        view.alignment = .leading
        return view
    }()

    // MARK: - Lifecycle
    override func configureHierarchy() {

        stackView.addArrangedSubview(titleShimmer)
        stackView.addArrangedSubview(subtitleShimmer)

        cityContentView.addSubview(thumbnailShimmer)
        cityContentView.addSubview(stackView)
        cityContentView.addSubview(chevronPlaceholder)

        contentView.addSubview(cityContentView)
    }

    override func configureLayout() {

        cityContentView.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(16)
            make.verticalEdges.equalToSuperview().inset(6)
        }

        thumbnailShimmer.snp.makeConstraints { make in
            make.leading.verticalEdges.equalToSuperview().inset(16)
            make.width.equalTo(thumbnailShimmer.snp.height)
        }

        stackView.snp.makeConstraints {
            $0.leading.equalTo(thumbnailShimmer.snp.trailing).offset(16)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualTo(chevronPlaceholder.snp.leading).offset(-12)
        }

        titleShimmer.snp.makeConstraints {
            $0.height.equalTo(18)
            $0.width.equalTo(140)
        }

        subtitleShimmer.snp.makeConstraints {
            $0.height.equalTo(14)
            $0.width.equalTo(80)
        }

        chevronPlaceholder.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(CGSize(width: 12, height: 12))
        }
    }

    override func configureView() {
        backgroundColor = .systemGray6
        selectionStyle = .none
    }
    
    func start() {
        thumbnailShimmer.startShimmering()
        titleShimmer.startShimmering()
        subtitleShimmer.startShimmering()
    }

    func stop() {
        thumbnailShimmer.stopShimmering()
        titleShimmer.stopShimmering()
        subtitleShimmer.stopShimmering()
    }
}
