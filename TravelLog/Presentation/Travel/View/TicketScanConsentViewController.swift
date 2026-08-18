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

    // 국외 이전 고지 블록이 추가되며 내용이 길어질 수 있어, 내용이 화면보다 길면
    // 스크롤되도록 한다. cardView 자체는 safeArea에 required로 고정된 프레임을
    // 가지므로(아래 configureLayout 참고), scrollView의 프레임 높이도 항상 확정된
    // 값으로 계산된다 — 내용 크기에 프레임 높이가 거꾸로 의존하는 순환 참조가 없다.
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
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

    private let transferNoticeTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "개인정보 국외 이전 및 위탁 고지"
        label.font = .boldSystemFont(ofSize: 12)
        label.textColor = .black
        return label
    }()

    // 「개인정보 보호법」 제28조의8이 요구하는 국외 이전 고지사항(이전받는 자/국가/
    // 항목/목적/보유기간/거부권)을 동의 시점에 바로 확인할 수 있도록 명시한다.
    // 보관기간은 Anthropic 쪽 정책이라 구체 일수 대신 처리방침 참조를 안내한다 —
    // 정책이 바뀌면 처리방침(웹페이지)만 고치면 되고, 이 화면(앱 바이너리)은
    // 다시 빌드하지 않아도 되게 하기 위함이다.
    private let transferNoticeBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.text = """
        · 이전받는 자: Anthropic, PBC
        · 이전 국가: 미국
        · 이전 항목: 확인 및 마스킹을 마친 티켓 이미지
        · 이전 목적: AI를 통한 여정 정보(출발지·도착지·일시·교통수단) 추출
        · 보유 및 이용 기간: Anthropic 정책에 따라 처리되며 모델 학습에는 사용되지 않습니다. 최신 보관기간은 개인정보처리방침에서 확인할 수 있습니다.
        · 동의를 거부할 수 있으며, 거부 시 AI 인식 기능만 제한되고 수동 입력 등 다른 기능은 계속 이용할 수 있습니다.
        """
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

        cardView.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

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
        contentStackView.addArrangedSubview(transferNoticeTitleLabel)
        contentStackView.addArrangedSubview(transferNoticeBodyLabel)
        // 제목과 본문은 한 블록으로 보여야 해서, contentStackView의 기본 spacing(16)
        // 대신 더 좁은 간격을 준다.
        contentStackView.setCustomSpacing(4, after: transferNoticeTitleLabel)

        // 버튼을 스크롤 밖에 고정하지 않고 콘텐츠 맨 마지막 항목으로 넣어서,
        // 내용이 화면보다 길면 끝까지 스크롤해야 "동의" 버튼이 나오게 한다.
        // 화면이 커서 내용이 다 보이는 경우엔 자연히 버튼도 바로 보인다.
        contentStackView.addArrangedSubview(buttonStackView)

        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(agreeButton)
    }

    override func configureLayout() {
        dimmedBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // cardView 자신은 top/bottom을 직접 고정하지 않는다 — centerY와, 아래
        // scrollView→cardView로 이어지는 bottom-up 체인이 합쳐져서 높이가 결정된다
        // (내용이 짧으면 카드도 작아지고, 길면 scrollView의 상한 캡에 걸려 그 안
        // (버튼 포함)에서만 스크롤된다). top/bottom 부등식은 혹시 모를 경우를 막는
        // 안전판일 뿐, 실제 크기를 정하는 제약이 아니다.
        cardView.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide).offset(20)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-20)
            make.centerY.equalToSuperview()
            make.horizontalEdges.equalToSuperview().inset(24)
        }

        iconImageView.snp.makeConstraints { make in
            make.size.equalTo(20)
        }

        headerStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.verticalEdges.equalToSuperview()
        }

        // 버튼(동의 포함)이 이제 contentStackView 맨 마지막 항목이라, 스크롤 끝까지
        // 내려야만 보인다. scrollView의 높이는 (1) 내용 크기와 최대한 같아지려
        // 하되(우선순위 750), (2) safeArea 대비 여유 공간(카드 상하 여백만, 약
        // 100pt)을 절대 넘지 않는다(우선순위 1000, 필수). 내용이 짧으면 (1)이
        // 그대로 적용돼 카드가 내용만큼만 커지고(이 경우 버튼도 바로 보임), 내용이
        // 길면 (2)가 이겨서 그 높이에서 잘리고 스크롤이 생긴다 — 이 두 값이
        // cardView 자체를 참조하지 않으므로(contentStackView의 고유 크기와
        // safeAreaLayoutGuide만 참조) 순환 참조가 생기지 않는다.
        scrollView.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().inset(24)
            make.height.lessThanOrEqualTo(view.safeAreaLayoutGuide).offset(-100)
            make.height.equalTo(contentStackView).priority(.high)
        }

        contentStackView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        buttonStackView.snp.makeConstraints { make in
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
