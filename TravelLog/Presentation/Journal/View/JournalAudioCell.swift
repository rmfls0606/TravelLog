//
//  JournalAudioCell.swift
//  TravelLog
//
//  Created by ChatGPT on 2025/xx/xx.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

/// 타임라인용 음성 블록 셀 (타임라인 선/점 + 카드 내부에 재생 UI)
final class JournalAudioCell: BaseTableViewCell {

    static let reuseIdentifier = "JournalAudioCell"

    // Timeline UI
    private let timelineLine = UIView()
    private let dotView = UIView()
    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let locationLabel = UILabel()
    private let blockView = UIView()

    // Playback UI
    private let slider = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let controlsStack = UIStackView()
    private let back15Button = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let forward15Button = UIButton(type: .system)
    private lazy var sliderTap = UITapGestureRecognizer(target: self, action: #selector(handleSliderTap(_:)))

    var reuseBag = DisposeBag()
    private let controlBag = DisposeBag() // 내부 고정 바인딩 용
    private var timelineTopConstraint: Constraint?
    private var dotTopConstraint: Constraint?

    // Outputs
    let playTapped = PublishRelay<Void>()
    let skipBackwardTapped = PublishRelay<Void>()
    let skipForwardTapped = PublishRelay<Void>()
    let seekChanged = PublishRelay<Float>() // 0.0 ~ 1.0

    override func prepareForReuse() {
        super.prepareForReuse()
        reuseBag = DisposeBag()
        isUserInteractionEnabled = true
        playPauseButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        slider.value = 0
        currentTimeLabel.text = "00:00"
        durationLabel.text = "00:00"
        locationLabel.text = nil
        timelineTopConstraint?.update(offset: 0)
        dotTopConstraint?.update(offset: 20)
    }

    // MARK: - Base overrides
    override func configureHierarchy() {
        contentView.addSubviews(timelineLine, dotView, cardView)
        cardView.addSubviews(timeLabel, locationLabel, blockView)
        blockView.addSubviews(slider, currentTimeLabel, durationLabel, controlsStack)
        [back15Button, playPauseButton, forward15Button].forEach { controlsStack.addArrangedSubview($0) }
    }

    override func configureLayout() {
        timelineLine.snp.makeConstraints {
            $0.width.equalTo(2)
            $0.leading.equalToSuperview().inset(24)
            $0.bottom.equalToSuperview()
            timelineTopConstraint = $0.top.equalToSuperview().constraint
        }
        dotView.snp.makeConstraints {
            $0.centerX.equalTo(timelineLine)
            dotTopConstraint = $0.top.equalToSuperview().inset(20).constraint
            $0.size.equalTo(14)
        }
        cardView.snp.makeConstraints {
            $0.leading.equalTo(timelineLine.snp.trailing).offset(16)
            $0.trailing.equalToSuperview().inset(16)
            $0.top.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(8)
        }

        timeLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(16)
        }
        locationLabel.snp.makeConstraints {
            $0.centerY.equalTo(timeLabel)
            $0.trailing.equalToSuperview().inset(16)
        }

        blockView.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
        }

        slider.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        currentTimeLabel.snp.makeConstraints {
            $0.top.equalTo(slider.snp.bottom).offset(4)
            $0.leading.equalTo(slider)
        }
        durationLabel.snp.makeConstraints {
            $0.centerY.equalTo(currentTimeLabel)
            $0.trailing.equalTo(slider)
        }
        controlsStack.snp.makeConstraints {
            $0.top.equalTo(currentTimeLabel.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(12)
        }
    }

    override func configureView() {
        selectionStyle = .none
        backgroundColor = .clear

        timelineLine.backgroundColor = .systemGray5
        dotView.backgroundColor = .systemOrange
        dotView.layer.cornerRadius = 7

        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 14
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowRadius = 3
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)

        blockView.layer.cornerRadius = 12
        blockView.clipsToBounds = true
        blockView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.08)

        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray
        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = .darkGray

        slider.tintColor = .systemOrange
        slider.minimumValue = 0
        slider.maximumValue = 1
        let clearThumb = UIImage()
        slider.setThumbImage(clearThumb, for: .normal)
        slider.setThumbImage(clearThumb, for: .highlighted)
        slider.addGestureRecognizer(sliderTap)

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .secondaryLabel
        currentTimeLabel.text = "00:00"

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = .secondaryLabel
        durationLabel.text = "00:00"

        controlsStack.axis = .horizontal
        controlsStack.spacing = 32

        back15Button.setPreferredSymbolConfiguration(.init(pointSize: 26, weight: .medium), forImageIn: .normal)
        playPauseButton.setPreferredSymbolConfiguration(.init(pointSize: 32, weight: .semibold), forImageIn: .normal)
        forward15Button.setPreferredSymbolConfiguration(.init(pointSize: 26, weight: .medium), forImageIn: .normal)

        back15Button.setImage(UIImage(systemName: "gobackward.15"), for: .normal)
        playPauseButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        forward15Button.setImage(UIImage(systemName: "goforward.15"), for: .normal)

        back15Button.tintColor = .systemGray
        playPauseButton.tintColor = .systemOrange
        forward15Button.tintColor = .systemGray

        slider.rx.value
            .distinctUntilChanged()
            .bind(to: seekChanged)
            .disposed(by: controlBag)

        back15Button.rx.tap.bind(to: skipBackwardTapped).disposed(by: controlBag)
        forward15Button.rx.tap.bind(to: skipForwardTapped).disposed(by: controlBag)
        playPauseButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.playTapped.accept(())
            }
            .disposed(by: controlBag)
    }

    // MARK: - Public API
    func configure(with block: JournalBlockTable) {
        timeLabel.text = formatKoreanTime(block.createdAt)
        locationLabel.text = block.placeName ?? "위치 없음"
    }

    func setDuration(_ seconds: TimeInterval) {
        durationLabel.text = format(seconds)
    }

    func updateCurrentTime(_ seconds: TimeInterval, progress: Double) {
        currentTimeLabel.text = format(seconds)
        slider.value = Float(progress)
    }

    func setPlaying(_ isPlaying: Bool) {
        let symbol = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        playPauseButton.setImage(UIImage(systemName: symbol), for: .normal)
    }

    func setIsFirstInTimeline(_ isFirst: Bool) {
        timelineTopConstraint?.update(offset: isFirst ? 16 : 0)
        dotTopConstraint?.update(offset: isFirst ? 36 : 32)
    }

    private func format(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t)/60, Int(t)%60)
    }

    private func formatKoreanTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a hh:mm"
        return f.string(from: date)
    }

    @objc
    private func handleSliderTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: slider)
        let width = slider.bounds.width
        guard width > 0 else { return }
        let ratio = min(max(0, point.x / width), 1)
        slider.value = Float(ratio)
        seekChanged.accept(Float(ratio))
    }
}
