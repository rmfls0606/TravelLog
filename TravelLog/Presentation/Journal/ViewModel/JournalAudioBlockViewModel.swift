//
//  JournalAudioBlockViewModel.swift
//  TravelLog
//
//  Created by 이상민 on 11/20/25.
//

import Foundation
import AVFoundation
import UIKit
import RxSwift
import RxCocoa

final class JournalAudioBlockViewModel {

    private class AudioCoordinator {
        static let shared = AudioCoordinator()
        private init() {}
        
        weak var recordingVM: JournalAudioBlockViewModel?
        weak var playingVM: JournalAudioBlockViewModel?
        
        func beginRecording(_ vm: JournalAudioBlockViewModel) {
            if let other = recordingVM, other !== vm {
                other.stopAll(external: true)
            }
            if let other = playingVM, other !== vm {
                other.stopAll(external: true)
            }
            recordingVM = vm
            playingVM = nil
        }
        
        func beginPlayback(_ vm: JournalAudioBlockViewModel) {
            if let other = recordingVM, other !== vm {
                other.stopAll(external: true)
            }
            if let other = playingVM, other !== vm {
                other.stopAll(external: true)
            }
            playingVM = vm
            recordingVM = nil
        }
        
        func clearIfNeeded(_ vm: JournalAudioBlockViewModel) {
            if recordingVM === vm { recordingVM = nil }
            if playingVM === vm { playingVM = nil }
        }
    }

    // MARK: - Input / Output
    struct Input {
        let recordTapped: Observable<Void>
        let stopTapped: Observable<Void>
        let playTapped: Observable<Void>
        let skipBackwardTapped: Observable<Void>
        let skipForwardTapped: Observable<Void>
    }

    struct Output {
        let isRecording: Driver<Bool>
        let isPlaying: Driver<Bool>
        let currentTime: Driver<String>
        let totalDuration: Driver<String>
        let playbackProgress: Driver<Double>
        let waveformLevel: Driver<Float>
        let alertMessage: Signal<String>
        let resetToIdle: Signal<Void>
    }

    // MARK: - Private
    private let disposeBag = DisposeBag()
    private let audioSession = AVAudioSession.sharedInstance()
    private var isSessionActive = false

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private(set) var recordedFileURL: URL?
    private(set) var recordedDuration: TimeInterval = 0
    private let progressRelay = BehaviorRelay<Double>(value: 0)
    private let coordinator = AudioCoordinator.shared

    private let isRecordingRelay = BehaviorRelay(value: false)
    private let isPlayingRelay = BehaviorRelay(value: false)
    private let currentTimeRelay = BehaviorRelay(value: "00:00")
    private let durationRelay = BehaviorRelay(value: "00:00")
    private let waveformRelay = BehaviorRelay<Float>(value: 0.0)
    private let alertRelay = PublishRelay<String>()
    private let resetRelay = PublishRelay<Void>()

    // MARK: - Transform
    func transform(_ input: Input) -> Output {
        setupNotifications()

        input.recordTapped
            .bind(with: self) {
                owner, _ in
                owner.onRecordTapped()
            }
            .disposed(by: disposeBag)

        input.stopTapped
            .bind(with: self) { owner, _ in owner.stopAll() }
            .disposed(by: disposeBag)

        input.playTapped
            .bind(with: self) { owner, _ in owner.togglePlayback() }
            .disposed(by: disposeBag)

        input.skipBackwardTapped
            .bind(with: self) { owner, _ in owner.skip(seconds: -15) }
            .disposed(by: disposeBag)

        input.skipForwardTapped
            .bind(with: self) { owner, _ in owner.skip(seconds: 15) }
            .disposed(by: disposeBag)

        return Output(
            isRecording: isRecordingRelay.asDriver(),
            isPlaying: isPlayingRelay.asDriver(),
            currentTime: currentTimeRelay.asDriver(),
            totalDuration: durationRelay.asDriver(),
            playbackProgress: progressRelay.asDriver(),
            waveformLevel: waveformRelay.asDriver(),
            alertMessage: alertRelay.asSignal(),
            resetToIdle: resetRelay.asSignal()
        )
    }

    // MARK: - Actions
    private func onRecordTapped() {
        guard audioSession.isInputAvailable else {
            alertRelay.accept("마이크 입력을 찾을 수 없습니다.")
            return
        }
        checkPermissionAndRecord()
    }

    // MARK: - Permissions + Start Recording
    private func checkPermissionAndRecord() {

        guard activateSession(category: .playAndRecord,
                              mode: .default,
                              options: [.allowBluetooth, .defaultToSpeaker]) else {
            alertRelay.accept("오디오 세션 실패")
            return
        }

        switch audioSession.recordPermission {
        case .granted:
            startRecording()

        case .denied:
            presentSettingsAlert()

        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startRecording() }
                    else { self?.alertRelay.accept("마이크 접근이 필요합니다.") }
                }
            }

        @unknown default:
            alertRelay.accept("마이크 권한을 확인할 수 없습니다.")
        }
    }

    // MARK: - Start Recording
    private func startRecording() {
        guard isRecordingRelay.value == false else { return }

        coordinator.beginRecording(self)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("record_\(UUID().uuidString).m4a")

        recordedFileURL = url
        recordedDuration = 0
        durationRelay.accept("00:00")
        currentTimeRelay.accept("00:00")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true //리벨 측정 활성화

            if recorder?.record() == false {
                alertRelay.accept("녹음을 시작할 수 없습니다. record() 실패.")
                return
            }

            isRecordingRelay.accept(true)
            isPlayingRelay.accept(false)
            startTimer()

        } catch {
            alertRelay.accept("녹음 오류 발생: \(error.localizedDescription)")
        }
    }

    // MARK: - Stop
    func stopAll(external: Bool = false) {
        if isRecordingRelay.value {
            recordedDuration = recorder?.currentTime ?? 0
            durationRelay.accept(format(recordedDuration))
            currentTimeRelay.accept("00:00")
            recorder?.stop()
            isRecordingRelay.accept(false)
            progressRelay.accept(0)
            // 1초 미만이면 무시
            if recordedDuration < 1 {
                if let url = recordedFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                recordedFileURL = nil
                alertRelay.accept("음성 기록이 너무 짧습니다.")
                progressRelay.accept(0)
                waveformRelay.accept(0)
                durationRelay.accept("00:00")
                resetRelay.accept(())
            }
        }
        if isPlayingRelay.value {
            if external {
                pausePlaybackKeepingPosition()
            } else {
                player?.stop()
                isPlayingRelay.accept(false)
                progressRelay.accept(0)
            }
        }
        if !external {
            progressRelay.accept(0)
            stopTimer()
        }
        if !isRecordingRelay.value && !isPlayingRelay.value && !external {
            deactivateSession()
        }
        coordinator.clearIfNeeded(self)
    }

    private func pausePlaybackKeepingPosition() {
        guard isPlayingRelay.value else { return }
        if let player {
            player.pause()
            let current = player.currentTime
            currentTimeRelay.accept(format(current))
            let total = player.duration
            let progress = total > 0 ? current / total : 0
            progressRelay.accept(progress)
        }
        isPlayingRelay.accept(false)
        stopTimer()
    }

    // MARK: - Playback
    private func togglePlayback() {
        guard !isRecordingRelay.value else {
            alertRelay.accept("녹음 중에는 재생할 수 없습니다.")
            return
        }

        guard let url = recordedFileURL else {
            alertRelay.accept("재생할 녹음이 없습니다.")
            return
        }

        // 이미 재생 중이면 일시정지
        if let player, player.isPlaying {
            player.pause()
            isPlayingRelay.accept(false)
            stopTimer()
            deactivateSession()
            return
        }

        coordinator.beginPlayback(self)
        do {
            guard activateSession(category: .playback, mode: .default) else {
                alertRelay.accept("오디오 세션 실패")
                return
            }
            // 기존 플레이어가 없거나 파일이 변경된 경우 새로 준비
            if player == nil || player?.url != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.isMeteringEnabled = true
                player?.prepareToPlay()
                recordedDuration = player?.duration ?? recordedDuration
                durationRelay.accept(format(recordedDuration))
            }

            if let player {
                // 끝까지 재생된 상태였다면 처음부터 다시
                if player.currentTime >= player.duration {
                    player.currentTime = 0
                    progressRelay.accept(0)
                    currentTimeRelay.accept(format(0))
                } else {
                    // 기존 위치에서 이어듣기
                    let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    progressRelay.accept(progress)
                    currentTimeRelay.accept(format(player.currentTime))
                }
                player.play()
            }

            isPlayingRelay.accept(true)
            startTimer()

        } catch {
            alertRelay.accept("재생 오류: \(error.localizedDescription)")
            deactivateSession()
        }
    }

    private func skip(seconds: TimeInterval) {
        guard let player else { return }
        let newTime = max(0, min(player.duration, player.currentTime + seconds))
        player.currentTime = newTime
        currentTimeRelay.accept(format(newTime))
        let progress = player.duration > 0 ? newTime / player.duration : 0
        progressRelay.accept(progress)
    }

    // MARK: - Timer + Waveform
    private func startTimer() {
        stopTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }

            if isRecordingRelay.value {
                recorder?.updateMeters()
                let avg = recorder?.averagePower(forChannel: 0) ?? -160
                waveformRelay.accept(normalizedLevel(from: avg))
                currentTimeRelay.accept(format(recorder?.currentTime ?? 0))

            } else if isPlayingRelay.value {
                player?.updateMeters()
                let avg = player?.averagePower(forChannel: 0) ?? -160
                waveformRelay.accept(normalizedLevel(from: avg))
                let current = player?.currentTime ?? 0
                let total = player?.duration ?? recordedDuration
                currentTimeRelay.accept(format(current))
                let progress = total > 0 ? current / total : 0
                progressRelay.accept(min(1, max(0, progress)))

                if let player, !player.isPlaying {
                    isPlayingRelay.accept(false)
                    stopTimer()
                    currentTimeRelay.accept(format(player.duration))
                    progressRelay.accept(1)
                    deactivateSession()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func normalizedLevel(from power: Float) -> Float {
        let minDb: Float = -60
        guard power > minDb else { return 0 }
        let clamped = min(0, power)
        let linear = (clamped - minDb) / (-minDb) // 0...1
        return pow(linear, 2.2) // emphasize loud parts, shrink quiet parts
    }

    // MARK: - Audio Session Helpers
    private func activateSession(category: AVAudioSession.Category,
                                 mode: AVAudioSession.Mode,
                                 options: AVAudioSession.CategoryOptions = []) -> Bool {
        do {
            // 이미 활성화되어 있으면 외부 세션에 신호를 보내지 않고 유지
            if !isSessionActive {
                try audioSession.setCategory(category, mode: mode, options: options)
                try audioSession.setActive(true, options: [])
                isSessionActive = true
            } else {
                // 카테고리만 최신으로 갱신
                try? audioSession.setCategory(category, mode: mode, options: options)
            }
            return true
        } catch {
            isSessionActive = false
            return false
        }
    }

    private func deactivateSession() {
        if isSessionActive {
            try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        }
        isSessionActive = false
    }

    // --------------------------------------------------------------------
    // MARK: - Settings Alert
    // --------------------------------------------------------------------
    private func presentSettingsAlert() {
        DispatchQueue.main.async {
            guard let topVC = self.topViewController() else { return }
            let alert = UIAlertController(
                title: nil,
                message: "음성녹음 기능을 사용하려면 ‘마이크’ 접근 권한을 허용해야 합니다.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "설정", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }))
            topVC.present(alert, animated: true)
        }
    }

    private func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
        .first?.rootViewController) -> UIViewController? {

        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }

    // MARK: - Notifications (Interruptions / Route Changes)
    private func setupNotifications() {
        NotificationCenter.default.rx.notification(AVAudioSession.interruptionNotification)
            .bind(with: self) { owner, notification in
                owner.handleInterruption(notification)
            }
            .disposed(by: disposeBag)

        NotificationCenter.default.rx.notification(AVAudioSession.routeChangeNotification)
            .bind(with: self) { owner, notification in
                owner.handleRouteChange(notification)
            }
            .disposed(by: disposeBag)

        // 컨트롤센터(WillResignActive)에서는 끊지 않음. 백그라운드 진입 시에만 안전 중지
        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
            .bind(with: self) { owner, _ in owner.stopAll() }
            .disposed(by: disposeBag)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            stopAll()
            // 외부 작업(전화/기타 앱)으로 중단될 때만 알림 표시
            alertRelay.accept("오디오 세션이 다른 작업으로 중단되었습니다.")
        case .ended:
            // 세션 재활성화 시도 (필요 시)
            try? audioSession.setActive(true)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        switch reason {
        case .oldDeviceUnavailable, .routeConfigurationChange:
            // 이어폰 분리/오디오 경로 변경 시 안전하게 정지
            stopAll()
        default:
            break
        }
    }

    private func format(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t)/60, Int(t)%60)
    }
}
