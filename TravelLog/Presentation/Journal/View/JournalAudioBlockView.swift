//
//  JournalAudioBlockView.swift
//  TravelLog
//
//  Created by 이상민 on 11/19/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import Toast

final class JournalAudioBlockView: BaseView {

    private let headerStack = UIStackView()
    private let typeIcon = UIImageView(image: UIImage(systemName: "mic"))
    private let typeLabel = UILabel()
    private let timeLabel = UILabel()
    private let removeButton = UIButton(type: .system)

    private let dashBox = UIView()
    private let stateButton = UIButton(type: .system)
    private let playbackTimeLabel = UILabel()
    private let placeholderLabel = UILabel()
    private let placeholderStack = UIStackView()
    private let dashTapGesture = UITapGestureRecognizer()

    private let waveformView = AudioWaveformView()
    private let controlStack = UIStackView()
    private let back15Button = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let forward15Button = UIButton(type: .system)

    let disposeBag = DisposeBag()

    private let viewModel: JournalAudioBlockViewModel
    private var audioState: AudioState = .idle {
        didSet { updateUI(for: audioState) }
    }
    private let dashBorderLayer = CAShapeLayer()
    private var placeholderStackTopConstraint: Constraint?
    private var placeholderStackCenterYConstraint: Constraint?

    let recordTapped = PublishRelay<Void>()
    let stopTapped = PublishRelay<Void>()
    let playTapped = PublishRelay<Void>()
    let skipBackwardTapped = PublishRelay<Void>()
    let skipForwardTapped = PublishRelay<Void>()
    let removeTapped = PublishRelay<Void>()

    private enum AudioState {
        case idle
        case recording
        case playback
    }

    // MARK: - Init
    init(vm: JournalAudioBlockViewModel) {
        self.viewModel = vm   // keep strong reference
        super.init(frame: .zero)
        setupView()
        setupLayout()
        bind(vm)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashBorderLayer.frame = dashBox.bounds
        dashBorderLayer.path = UIBezierPath(roundedRect: dashBox.bounds, cornerRadius: 12).cgPath
    }

    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor

        addSubview(headerStack)
        addSubview(dashBox)
        dashBox.addSubview(placeholderStack)
        dashBox.addSubview(waveformView)
        dashBox.addSubview(playbackTimeLabel)
        dashBox.addSubview(controlStack)
        dashBox.addGestureRecognizer(dashTapGesture)

        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.addArrangedSubview(typeIcon)
        headerStack.addArrangedSubview(typeLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(removeButton)

        typeIcon.tintColor = .systemOrange
        typeLabel.text = "음성"
        typeLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        typeLabel.textColor = .systemOrange

        timeLabel.text = formatTime(Date())
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray

        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .systemGray3

        dashBox.layer.cornerRadius = 12
        dashBox.backgroundColor = .systemGray6.withAlphaComponent(0.2)
        dashBox.layer.addSublayer(dashBorderLayer)

        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 8
        placeholderStack.addArrangedSubview(stateButton)
        placeholderStack.addArrangedSubview(placeholderLabel)

        stateButton.tintColor = .systemOrange
        stateButton.isUserInteractionEnabled = true
        stateButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32, weight: .regular),
            forImageIn: .normal
        )
        stateButton.imageView?.contentMode = .scaleAspectFit
        stateButton.contentHorizontalAlignment = .center
        stateButton.contentVerticalAlignment = .center

        playbackTimeLabel.text = "00:00"
        playbackTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        playbackTimeLabel.textColor = .darkGray
        playbackTimeLabel.textAlignment = .center
        playbackTimeLabel.isHidden = true

        placeholderLabel.text = "녹음 시작하기"
        placeholderLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        placeholderLabel.textColor = .darkGray
        placeholderLabel.textAlignment = .center
        placeholderLabel.isHidden = false

        dashBorderLayer.strokeColor = UIColor.systemGray4.cgColor
        dashBorderLayer.fillColor = UIColor.clear.cgColor
        dashBorderLayer.lineDashPattern = [6, 4]
        dashBorderLayer.lineWidth = 1

        waveformView.isHidden = true
        controlStack.isHidden = true

        controlStack.axis = .horizontal
        controlStack.spacing = 40

        back15Button.setImage(UIImage(systemName: "gobackward.15"), for: .normal)
        playPauseButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        forward15Button.setImage(UIImage(systemName: "goforward.15"), for: .normal)

        back15Button.tintColor = .systemGray
        playPauseButton.tintColor = .systemOrange
        forward15Button.tintColor = .systemGray
        [back15Button, playPauseButton, forward15Button].forEach { controlStack.addArrangedSubview($0) }

        // 상태 버튼 탭: 녹음/정지/재생 토글
        stateButton.rx.tap
            .bind(with: self) { owner, _ in
                switch owner.audioState {
                case .idle:
                    owner.recordTapped.accept(())
                case .recording:
                    owner.stopTapped.accept(())
                case .playback:
                    owner.playTapped.accept(())
                }
            }
            .disposed(by: disposeBag)

        // 대시 전체 탭: placeholder 상태에서 녹음 시작
        dashTapGesture.rx.event
            .bind(with: self) { owner, _ in
                if owner.audioState == .idle {
                    owner.recordTapped.accept(())
                }
            }
            .disposed(by: disposeBag)

        updateUI(for: .idle)
    }
    
    private func setupLayout() {
        headerStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.horizontalEdges.equalToSuperview().inset(16)
        }

        dashBox.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
            $0.height.equalTo(160)
        }

        waveformView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(24)
            $0.horizontalEdges.equalToSuperview().inset(24)
            $0.height.equalTo(30)
        }

        playbackTimeLabel.snp.makeConstraints {
            $0.top.equalTo(waveformView.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
        }

        placeholderStack.snp.makeConstraints {
            placeholderStackTopConstraint = $0.top.equalTo(playbackTimeLabel.snp.bottom).offset(8).constraint
            placeholderStackCenterYConstraint = $0.centerY
                .equalToSuperview().constraint
            $0.centerX.equalToSuperview()
        }
        placeholderStackTopConstraint?.deactivate()
        placeholderStackCenterYConstraint?.activate()

        stateButton.snp.makeConstraints {
            $0.width.height.equalTo(44)
        }

        controlStack.snp.makeConstraints {
            $0.top.equalTo(playbackTimeLabel.snp.bottom).offset(16)
            $0.centerX.equalToSuperview()
        }
    }

    func bind(_ vm: JournalAudioBlockViewModel) {

        let input = JournalAudioBlockViewModel.Input(
            recordTapped: recordTapped.asObservable(),
            stopTapped: stopTapped.asObservable(),
            playTapped: playTapped.asObservable(),
            skipBackwardTapped: skipBackwardTapped.asObservable(),
            skipForwardTapped: skipForwardTapped.asObservable()
        )

        let output = vm.transform(input)

        removeButton.rx.tap.bind(to: removeTapped).disposed(by: disposeBag)

        // 재생 중에만 스킵 허용
        back15Button.rx.tap
            .withLatestFrom(output.isPlaying.asObservable())
            .filter { $0 }
            .map { _ in () }
            .bind(to: skipBackwardTapped)
            .disposed(by: disposeBag)

        forward15Button.rx.tap
            .withLatestFrom(output.isPlaying.asObservable())
            .filter { $0 }
            .map { _ in () }
            .bind(to: skipForwardTapped)
            .disposed(by: disposeBag)
        playPauseButton.rx.tap.bind(to: playTapped).disposed(by: disposeBag)

        // Recording 상태 변화
        output.isRecording
            .drive(with: self) { owner, isRec in
                owner.waveformView.strokeColor = .systemRed
                owner.playPauseButton.isEnabled = !isRec
                if isRec {
                    owner.audioState = .recording
                } else if owner.audioState == .recording {
                    owner.audioState = .playback
                }
            }
            .disposed(by: disposeBag)

        // Playing UI 변환
        output.isPlaying
            .drive(with: self) { owner, isPlay in
                owner.playPauseButton.setImage(
                    UIImage(systemName: isPlay ? "pause.circle.fill" : "play.circle.fill"),
                    for: .normal
                )
                if isPlay { owner.audioState = .playback }
            }
            .disposed(by: disposeBag)

        Driver
            .combineLatest(output.currentTime, output.totalDuration) { current, total in
                total == "00:00" ? current : "\(current) / \(total)"
            }
            .drive(playbackTimeLabel.rx.text)
            .disposed(by: disposeBag)

        output.waveformLevel
            .drive(with: self) { owner, level in
                if owner.audioState == .recording {
                    owner.waveformView.appendRecording(level: level)
                }
            }
            .disposed(by: disposeBag)

        output.resetToIdle
            .emit(with: self) { owner, _ in
                owner.audioState = .idle
                owner.waveformView.beginRecording()
                owner.playbackTimeLabel.text = "00:00"
            }
            .disposed(by: disposeBag)

        output.playbackProgress
            .drive(with: self) { owner, progress in
                owner.waveformView.updatePlayhead(progress: CGFloat(progress))
            }
            .disposed(by: disposeBag)

        output.alertMessage
            .emit(with: self) { owner, msg in
                var style = ToastStyle()
                style.backgroundColor = .systemRed
                style.messageColor = .white
                owner.makeToast(msg, duration: 2.0, position: .top, style: style)
            }
            .disposed(by: disposeBag)
    }

    private func updateUI(for state: AudioState) {
        switch state {
        case .idle:
            stateButton.isHidden = false
            stateButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
            stateButton.tintColor = .systemOrange
            waveformView.isHidden = true
            controlStack.isHidden = true
            playbackTimeLabel.isHidden = true
            placeholderLabel.isHidden = false
            placeholderStackCenterYConstraint?.activate()
            placeholderStackTopConstraint?.deactivate()
            setControlButtonsEnabled(false)

        case .recording:
            stateButton.isHidden = false
            stateButton.setImage(UIImage(systemName: "record.circle"), for: .normal)
            stateButton.tintColor = .systemRed
            waveformView.isHidden = false
            waveformView.beginRecording()
            controlStack.isHidden = true
            playbackTimeLabel.isHidden = false
            placeholderLabel.isHidden = true
            placeholderStackCenterYConstraint?.deactivate()
            placeholderStackTopConstraint?.activate()
            setControlButtonsEnabled(false)

        case .playback:
            stateButton.isHidden = true
            waveformView.isHidden = false
            controlStack.isHidden = false
            playbackTimeLabel.isHidden = false
            placeholderLabel.isHidden = true
            placeholderStackCenterYConstraint?.deactivate()
            placeholderStackTopConstraint?.activate()
            setControlButtonsEnabled(true)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "a hh:mm"
        return df.string(from: date)
    }

    private func setControlButtonsEnabled(_ isEnabled: Bool) {
        [back15Button, playPauseButton, forward15Button].forEach {
            $0.isEnabled = isEnabled
            $0.alpha = isEnabled ? 1.0 : 0.4
        }
    }
}

// MARK: - Waveform that preserves recorded samples and draws a playhead
private final class AudioWaveformView: UIView {

    private var recordedSamples: [CGFloat] = []   // 전체 샘플 보관 (재생용)
    private var visibleSamples: [CGFloat] = []    // 화면에 보이는 부분
    private let maxRecordedSamples = 4000
    private let barWidth: CGFloat = 2
    private let barSpacing: CGFloat = 4
    private enum Mode { case recording, playback }
    private var mode: Mode = .recording
    private var playbackProgress: CGFloat = 0     // 0...1 (재생 위치)

    var strokeColor: UIColor = .systemRed {
        didSet { setNeedsDisplay() }
    }
    var amplitudeScale: CGFloat = 0.8 {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func beginRecording() {
        recordedSamples.removeAll()
        visibleSamples.removeAll()
        playbackProgress = 0
        mode = .recording
        setNeedsDisplay()
    }

    func appendRecording(level: Float) {
        let clamped = max(0, min(1, CGFloat(level)))
        recordedSamples.append(clamped)
        if recordedSamples.count > maxRecordedSamples {
            recordedSamples.removeFirst(recordedSamples.count - maxRecordedSamples)
        }

        let visibleCount = currentVisibleCount()
        visibleSamples = Array(recordedSamples.suffix(visibleCount))
        setNeedsDisplay()
    }

    func updatePlayhead(progress: CGFloat) {
        guard !recordedSamples.isEmpty else { return }
        mode = .playback
        playbackProgress = max(0, min(1, progress))
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let samplesToDraw: [CGFloat] = (mode == .playback) ? recordedSamples : visibleSamples
        guard !samplesToDraw.isEmpty else { return }

        let midY = rect.midY
        let width = rect.width
        let bars: [CGFloat]
        let step: CGFloat

        if mode == .playback {
            let targetBars = Int(max(2, floor(width / (barWidth + barSpacing)))) // 꽉 채우되 너무 촘촘하지 않게
            bars = downsample(samplesToDraw, targetCount: targetBars)
            step = bars.count > 1 ? width / CGFloat(bars.count - 1) : width
        } else {
            bars = samplesToDraw
            step = barWidth + barSpacing
        }

        let maxHeight = rect.height / 2

        if mode == .playback {
            let playedCount = Int(CGFloat(bars.count) * playbackProgress)
            let playedPath = UIBezierPath()
            let remainingPath = UIBezierPath()
            var x: CGFloat = 0

            for (idx, sample) in bars.enumerated() {
                let amp = maxHeight * min(1, sample * amplitudeScale)
                let top = CGPoint(x: x, y: midY - amp)
                let bottom = CGPoint(x: x, y: midY + amp)
                if idx < playedCount {
                    playedPath.move(to: top)
                    playedPath.addLine(to: bottom)
                } else {
                    remainingPath.move(to: top)
                    remainingPath.addLine(to: bottom)
                }
                x += step
            }

            strokeColor.setStroke()
            playedPath.lineWidth = barWidth
            playedPath.lineCapStyle = .round
            playedPath.stroke()

            UIColor.systemGray3.setStroke()
            remainingPath.lineWidth = barWidth
            remainingPath.lineCapStyle = .round
            remainingPath.stroke()
        } else {
            let path = UIBezierPath()
            var x: CGFloat = 0
            for sample in bars {
                let amp = maxHeight * min(1, sample * amplitudeScale)
                path.move(to: CGPoint(x: x, y: midY - amp))
                path.addLine(to: CGPoint(x: x, y: midY + amp))
                x += step
                if x > width { break }
            }

            strokeColor.setStroke()
            path.lineWidth = barWidth
            path.lineCapStyle = .round
            path.stroke()
        }
    }

    private func currentVisibleCount() -> Int {
        Int(max(1, floor(bounds.width / (barWidth + barSpacing))))
    }

    private func downsample(_ samples: [CGFloat], targetCount: Int) -> [CGFloat] {
        guard samples.count > targetCount else { return samples }
        let chunkSize = max(1, samples.count / targetCount)
        var result: [CGFloat] = []
        var index = 0
        while index < samples.count {
            let end = min(samples.count, index + chunkSize)
            let slice = samples[index..<end]
            let avg = slice.reduce(0, +) / CGFloat(slice.count)
            result.append(avg)
            index += chunkSize
            if result.count >= targetCount { break }
        }
        return result
    }
}
