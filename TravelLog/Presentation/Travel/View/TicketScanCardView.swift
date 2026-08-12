//
//  TicketScanCardView.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import UIKit
import SnapKit

final class TicketScanCardView: BaseCardView {

    /// 이 값 미만의 confidence는 화면에서 "내용을 꼭 확인해달라"는 경고로 안내한다.
    static let lowConfidenceThreshold: Double = 0.5

    let tapGesture = UITapGestureRecognizer()

    private let contentView = UIView()

    private let iconView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "doc.text.viewfinder"))
        view.tintColor = .systemBlue
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "티켓으로 빠르게 채우기"
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "탑승권·승차권 사진 한 장이면 교통수단, 날짜, 도시를 자동으로 채워드려요"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .darkGray
        label.numberOfLines = 0
        return label
    }()

    private let rightIcon: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "chevron.right"))
        view.tintColor = .darkGray
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()

    override func configureHierarchy() {
        addSubview(contentView)
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        addSubview(rightIcon)
        addSubview(loadingIndicator)
    }

    override func configureLayout() {
        contentView.snp.makeConstraints { make in
            make.verticalEdges.equalToSuperview().inset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(rightIcon.snp.leading).offset(-12)
        }

        iconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(22)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.trailing.equalToSuperview()
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.bottom.equalToSuperview()
        }

        rightIcon.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(16)
            make.size.equalTo(14)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(rightIcon)
        }
    }

    override func configureView() {
        super.configureView()

        backgroundColor = .white
        addGestureRecognizer(tapGesture)
    }

    /// 스캔 진행 중에는 탭을 막고 우측 화살표 대신 로딩 인디케이터를 보여준다.
    func setLoading(_ isLoading: Bool) {
        isUserInteractionEnabled = !isLoading
        alpha = isLoading ? 0.6 : 1.0

        rightIcon.isHidden = isLoading
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
}
