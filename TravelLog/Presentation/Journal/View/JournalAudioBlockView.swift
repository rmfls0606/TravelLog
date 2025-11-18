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

final class JournalAudioBlockView: BaseView {
    
    // MARK: - Rx
    let disposeBag = DisposeBag()
    let recordTapped = PublishRelay<Void>()
    let skipBackwardTapped = PublishRelay<Void>()
    let skipForwardTapped = PublishRelay<Void>()
    let removeTapped = PublishRelay<Void>()
    
    // MARK: - 상태
    private var isRecording = false {
        didSet {
            updateRecordButtonAppearance()
            updateSkipButtonsState()
        }
    }
    private var isExpanded = false {
        didSet {
            updateContainerVisibility(animated: true)
        }
    }
    private var timer: Timer?
    private var elapsedSeconds: Int = 0 {
        didSet { updateDurationLabel() }
    }
    
    // MARK: - UI
    private let headerStack = UIStackView()
    private let typeIcon = UIImageView(image: UIImage(systemName: "mic.circle.fill"))
    private let typeLabel = UILabel()
    private let timeLabel = UILabel()
    private let removeButton = UIButton(type: .system)
    
    // --- 메인 컨테이너 ---
    private let audioContainer = UIView()
    
    // 기본 상태 뷰 (Idle)
    private let placeholderButton = UIButton(type: .system)
    private let placeholderLabel = UILabel()
    private let placeholderStack = UIStackView()
    
    // 확장 상태 뷰 (Recording UI)
    private let waveformStack = UIStackView()
    private let durationLabel = UILabel()
    private let controlStack = UIStackView()
    private let backwardButton = UIButton(type: .system)
    private let recordButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        configureAppearance()
        bindActions()
        simulateWaveform()
        updateContainerVisibility(animated: false)
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Setup
private extension JournalAudioBlockView {
    
    func setupView() {
        addSubview(headerStack)
        addSubview(audioContainer)
        
        // Header
        headerStack.addArrangedSubview(typeIcon)
        headerStack.addArrangedSubview(typeLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(removeButton)
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 6
        
        // Audio container
        audioContainer.addSubview(placeholderStack)
        audioContainer.addSubview(waveformStack)
        audioContainer.addSubview(durationLabel)
        audioContainer.addSubview(controlStack)
        
        // --- placeholder stack ---
        placeholderStack.axis = .vertical
        placeholderStack.alignment = .center
        placeholderStack.spacing = 8
        placeholderStack.addArrangedSubview(placeholderButton)
        placeholderStack.addArrangedSubview(placeholderLabel)
        
        // --- recording stack ---
        waveformStack.axis = .horizontal
        waveformStack.alignment = .center
        waveformStack.spacing = 3
        waveformStack.distribution = .fillEqually
        
        controlStack.axis = .horizontal
        controlStack.alignment = .center
        controlStack.distribution = .equalCentering
        controlStack.spacing = 40
        controlStack.addArrangedSubview(backwardButton)
        controlStack.addArrangedSubview(recordButton)
        controlStack.addArrangedSubview(forwardButton)
    }
    
    func setupLayout() {
        headerStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.horizontalEdges.equalToSuperview().inset(16)
        }
        
        audioContainer.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(12)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        
        // 기본 상태 (placeholder)
        placeholderStack.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        placeholderButton.snp.makeConstraints { $0.size.equalTo(CGSize(width: 60, height: 60)) }
        
        // 녹음 UI 상태
        waveformStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(16)
            $0.leading.equalToSuperview().inset(20)
            $0.trailing.equalTo(durationLabel.snp.leading).offset(-8)
        }
        
        durationLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalTo(waveformStack)
        }
        
        controlStack.snp.makeConstraints {
            $0.top.equalTo(waveformStack.snp.bottom).offset(12)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(16)
        }
    }
    
    func configureAppearance() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
        
        typeIcon.tintColor = .systemIndigo
        typeLabel.text = "음성"
        typeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        typeLabel.textColor = .systemIndigo
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        timeLabel.text = formatter.string(from: Date())
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray
        
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .systemGray3
        
        // audio container
        audioContainer.backgroundColor = .systemGray6
        audioContainer.layer.cornerRadius = 12
        
        // placeholder
        placeholderButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        placeholderButton.tintColor = .systemIndigo
        placeholderButton.contentVerticalAlignment = .fill
        placeholderButton.contentHorizontalAlignment = .fill
        
        placeholderLabel.text = "음성 녹음"
        placeholderLabel.font = .systemFont(ofSize: 15, weight: .medium)
        placeholderLabel.textColor = .darkGray
        
        // duration
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = .darkGray
        durationLabel.textAlignment = .right
        durationLabel.text = "00:00"
        
        // control buttons
        backwardButton.setImage(UIImage(systemName: "gobackward.15"), for: .normal)
        forwardButton.setImage(UIImage(systemName: "goforward.15"), for: .normal)
        backwardButton.tintColor = .label
        forwardButton.tintColor = .label
        recordButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        recordButton.tintColor = .systemRed
    }
    
    func bindActions() {
        removeButton.rx.tap.bind(to: removeTapped).disposed(by: disposeBag)
        
        // placeholder 버튼 누르면 녹음 UI로 전환
        placeholderButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.isExpanded = true
            }
            .disposed(by: disposeBag)
        
        // 녹음 버튼
        recordButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.isRecording.toggle()
                owner.isRecording ? owner.startTimer() : owner.stopTimer()
                owner.recordTapped.accept(())
            }
            .disposed(by: disposeBag)
        
        backwardButton.rx.tap.bind(to: skipBackwardTapped).disposed(by: disposeBag)
        forwardButton.rx.tap.bind(to: skipForwardTapped).disposed(by: disposeBag)
    }
}

// MARK: - UI 전환 / 상태 업데이트
private extension JournalAudioBlockView {
    func updateContainerVisibility(animated: Bool) {
        let change = {
            self.placeholderStack.alpha = self.isExpanded ? 0 : 1
            self.waveformStack.alpha = self.isExpanded ? 1 : 0
            self.durationLabel.alpha = self.isExpanded ? 1 : 0
            self.controlStack.alpha = self.isExpanded ? 1 : 0
        }
        
        if animated {
            UIView.transition(with: audioContainer, duration: 0.3, options: .transitionCrossDissolve, animations: change)
        } else {
            change()
        }
    }
    
    func updateRecordButtonAppearance() {
        UIView.animate(withDuration: 0.25) {
            self.recordButton.setImage(UIImage(systemName: self.isRecording ? "pause.circle.fill" : "circle.fill"), for: .normal)
            self.audioContainer.layer.borderWidth = self.isRecording ? 2 : 0
            self.audioContainer.layer.borderColor = self.isRecording ? UIColor.systemRed.cgColor : UIColor.clear.cgColor
        }
    }
    
    func updateSkipButtonsState() {
        let enabled = !isRecording
        backwardButton.isEnabled = enabled
        forwardButton.isEnabled = enabled
        let alpha: CGFloat = enabled ? 1.0 : 0.4
        backwardButton.alpha = alpha
        forwardButton.alpha = alpha
    }
}

// MARK: - Timer / Waveform
private extension JournalAudioBlockView {
    func startTimer() {
        elapsedSeconds = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateDurationLabel() {
        let min = elapsedSeconds / 60
        let sec = elapsedSeconds % 60
        durationLabel.text = String(format: "%02d:%02d", min, sec)
    }
    
    func simulateWaveform() {
        for _ in 0..<25 {
            let bar = UIView()
            bar.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.5)
            bar.layer.cornerRadius = 2
            waveformStack.addArrangedSubview(bar)
            
            bar.snp.makeConstraints {
                $0.width.equalTo(3)
                $0.height.equalTo(CGFloat.random(in: 8...38))
            }
            
//            UIView.animate(withDuration: 0.5,
//                           delay: Double.random(in: 0...1),
//                           options: [.repeat, .autoreverse],
//                           animations: {
//                bar.snp.updateConstraints {
//                    $0.height.equalTo(CGFloat.random(in: 8...38))
//                }
//                self.layoutIfNeeded()
//            })
        }
    }
}
