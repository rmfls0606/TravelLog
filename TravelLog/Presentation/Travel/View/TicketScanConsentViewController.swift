//
//  TicketScanConsentViewController.swift
//  TravelLog
//
//  Created by Claude on 8/16/26.
//
//  티켓 스캔 최초 사용 시 보여주는 데이터 처리 동의 화면. UIAlertController 대신
//  커스텀 카드로 만들어 세 단계 흐름을 보여주고, "확인" 단계만 배지·텍스트 색으로
//  가볍게 강조한다(배경색 블록 없이 깔끔하게 유지).
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class TicketScanConsentViewController: BaseViewController {
    /// 동의(true)/취소(false) 결과를 전달한다.
    var onDecision: ((Bool) -> Void)?

    private let disposeBag = DisposeBag()

    // MARK: - UI

    private let dimmedBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        return view
    }()

    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    // 아이콘 + 타이틀을 가로로 붙여서 중앙 정렬한다. headerContainerView가 스택 폭
    // 전체를 차지하고, 그 안에서 headerStackView는 내용 크기만큼만 차지해 중앙에 놓인다.
    private let headerContainerView = UIView()

    private let headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    private let iconImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        view.tintColor = .systemBlue
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "티켓 사진 처리 안내"
        label.font = .boldSystemFont(ofSize: 16)
        label.textColor = .black
        return label
    }()

    private let introLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "촬영한 티켓 사진은 여행 정보를 자동으로 채우기 위해 외부 AI 서비스(Anthropic)로 전송되어 분석됩니다. 전송 전에 아래 순서를 거칩니다."
        return label
    }()

    private let footerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .systemGray
        label.numberOfLines = 0
        label.text = "전송된 사진은 AI 모델 학습에는 쓰이지 않고, 최대 7일간 보관된 뒤 자동 삭제됩니다."
        return label
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("취소", for: .normal)
        button.setTitleColor(.darkGray, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 15)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 20
        return button
    }()

    private let agreeButton = PrimaryButton(title: "동의하고 계속하기")

    private let buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - Base template

    override func configureHierarchy() {
        view.addSubview(dimmedBackgroundView)
        view.addSubview(cardView)

        headerStackView.addArrangedSubview(iconImageView)
        headerStackView.addArrangedSubview(titleLabel)
        headerContainerView.addSubview(headerStackView)

        cardView.addSubview(contentStackView)
        cardView.addSubview(buttonStackView)

        contentStackView.addArrangedSubview(headerContainerView)
        contentStackView.addArrangedSubview(introLabel)
        contentStackView.addArrangedSubview(stepRow(
            number: 1,
            title: "민감정보 자동 마스킹",
            description: "여권번호·바코드 등 민감해 보이는 부분을 자동으로 가립니다.",
            emphasis: .normal
        ))
        contentStackView.addArrangedSubview(stepRow(
            number: 2,
            title: "가려진 사진 확인",
            description: "가려진 사진을 직접 확인하고, 필요하면 추가로 가리거나 다시 촬영할 수 있습니다.",
            emphasis: .highlighted(
                warning: "자동 인식이 모든 경우를 완벽히 잡아내지 못할 수 있습니다. 이 단계를 꼭 거쳐주세요."
            )
        ))
        contentStackView.addArrangedSubview(stepRow(
            number: 3,
            title: "확인 후 전송",
            description: "확인 후 \"전송\"을 눌러야만 실제로 전송됩니다.",
            emphasis: .normal
        ))
        contentStackView.addArrangedSubview(footerLabel)

        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(agreeButton)
    }

    override func configureLayout() {
        dimmedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // cardView는 스스로 높이를 갖지 않고, 아래 contentStackView/buttonStackView를
        // 감싸는 크기로 결정된다(bottom-up). safe area 상하한은 화면을 벗어나지 않게
        // 막는 유연한 경계일 뿐, 실제 높이를 정하는 제약이 아니다.
        cardView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(20)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalToSuperview().priority(.high)
            make.horizontalEdges.equalToSuperview().inset(24)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(20)
        }

        headerStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.verticalEdges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(24)
            make.bottom.equalTo(buttonStackView.snp.top).offset(-20)
        }

        buttonStackView.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
    }

    override func configureView() {
        view.backgroundColor = .clear
    }

    override func configureBind() {
        cancelButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.onDecision?(false)
            }
            .disposed(by: disposeBag)

        agreeButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.onDecision?(true)
            }
            .disposed(by: disposeBag)
    }

    // MARK: - Step row builder

    private enum StepEmphasis {
        case normal
        case highlighted(warning: String)
    }

    /// 번호 배지 + 제목 + 설명으로 이뤄진 한 단계를 만든다. `.highlighted`면 배지·제목·
    /// 경고 문구에만 색을 줘서(배경 없이) "여기서 꼭 확인해야 한다"는 걸 강조한다.
    private func stepRow(number: Int, title: String, description: String, emphasis: StepEmphasis) -> UIView {
        let isHighlighted: Bool
        let warningText: String?
        switch emphasis {
        case .normal:
            isHighlighted = false
            warningText = nil
        case .highlighted(let warning):
            isHighlighted = true
            warningText = warning
        }

        let container = UIView()

        let numberBadge: UIView = {
            let badge = UIView()
            badge.backgroundColor = isHighlighted ? .systemOrange : .systemBlue
            badge.layer.cornerRadius = 9
            let label = UILabel()
            label.text = "\(number)"
            label.font = .boldSystemFont(ofSize: 10)
            label.textColor = .white
            label.textAlignment = .center
            badge.addSubview(label)
            label.snp.makeConstraints { $0.edges.equalToSuperview() }
            return badge
        }()

        let titleLabel: UILabel = {
            let label = UILabel()
            label.text = title
            label.font = .boldSystemFont(ofSize: 14)
            label.textColor = isHighlighted ? .systemOrange : .black
            return label
        }()

        let descriptionLabel: UILabel = {
            let label = UILabel()
            label.text = description
            label.font = .systemFont(ofSize: 12)
            label.textColor = .darkGray
            label.numberOfLines = 0
            return label
        }()

        let textStackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 3

        if let warningText {
            let warningLabel = UILabel()
            warningLabel.text = "⚠︎ \(warningText)"
            warningLabel.font = .boldSystemFont(ofSize: 11)
            warningLabel.textColor = .systemOrange
            warningLabel.numberOfLines = 0
            textStackView.addArrangedSubview(warningLabel)
            textStackView.setCustomSpacing(6, after: descriptionLabel)
        }

        container.addSubview(numberBadge)
        container.addSubview(textStackView)

        numberBadge.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.size.equalTo(18)
        }

        textStackView.snp.makeConstraints { make in
            make.top.equalTo(numberBadge).offset(-1)
            make.leading.equalTo(numberBadge.snp.trailing).offset(10)
            make.trailing.bottom.equalToSuperview()
        }

        return container
    }
}
