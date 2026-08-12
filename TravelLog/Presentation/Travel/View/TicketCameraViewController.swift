//
//  TicketCameraViewController.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//
//  티켓 스캔 전용 커스텀 카메라 화면. 별도의 "사진 촬영" 단계 없이, 화면 중앙의
//  직사각형(티켓/카드 비율) 가이드 안에 티켓이 들어오면 실시간으로 인식해 테두리가
//  초록색으로 바뀌고, 그 순간의 화면(라이브 프레임)을 그대로 잘라서 결과로 전달한다.
//  (인식이 잘 안 될 때를 대비해 셔터 버튼으로 수동 트리거도 항상 가능 — 이 역시 사진을
//  새로 찍는 게 아니라 같은 방식으로 "지금 화면"을 잘라서 쓴다.)
//
//  인식 판정은 두 단계로 이루어진다:
//   1) 문서 인식(VNDetectDocumentSegmentationRequest) — 사각형 문서 형태인지 확인
//   2) 텍스트 인식(VNRecognizeTextRequest) — 그 사각형 안에 읽을 수 있는 글자가
//      충분히 있는지 확인 (책, 카드, 상자 등 "모양만 비슷한" 물체를 걸러내기 위함)
//  두 조건을 모두 만족해야 "티켓처럼 보인다"고 판단한다.
//

import UIKit
import AVFoundation
import Vision
import SnapKit

protocol TicketCameraViewControllerDelegate: AnyObject {
    func ticketCamera(_ controller: TicketCameraViewController, didCapture image: UIImage)
    func ticketCameraDidCancel(_ controller: TicketCameraViewController)
}

final class TicketCameraViewController: BaseViewController {

    weak var delegate: TicketCameraViewControllerDelegate?

    // MARK: - Capture session

    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.travellog.ticketCamera.session")
    private let visionQueue = DispatchQueue(label: "com.travellog.ticketCamera.vision")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isSessionConfigured = false

    /// 프레임을 UIImage로 변환할 때 재사용하는 컨텍스트 (매번 새로 만들면 비용이 크다).
    private let ciContext = CIContext()
    /// 가장 최근에 들어온 프레임 — 인식 성공 시 "사진을 새로 찍지" 않고 이 프레임을 그대로 사용한다.
    /// visionQueue(쓰기)와 메인 스레드(읽기)에서 동시에 접근하므로 lock으로 보호한다.
    private var latestPixelBuffer: CVPixelBuffer?
    private let latestPixelBufferLock = NSLock()

    // MARK: - Live recognition state

    /// 연속으로 이만큼 "잘 인식됨" 판정이 나오면 자동으로 결과를 확정한다.
    private static let requiredAlignedStreak = 5
    /// 매 프레임마다 분석하지 않도록 최소 간격을 둔다.
    private static let analysisMinInterval: TimeInterval = 0.15
    /// 문서 형태가 인식된 뒤, "티켓처럼 보인다"고 판단하기 위한 최소 인식 글자 수.
    private static let minimumRecognizedCharacterCount = 10

    private var lastAnalysisDate = Date.distantPast
    private var alignedStreak = 0
    private var isCapturing = false

    // MARK: - UI

    private let previewContainerView = UIView()
    private let guideOverlay = TicketCameraGuideOverlayView()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        return button
    }()

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.text = "사각형 안에 티켓을 맞추면 자동으로 인식돼요"
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let shutterButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 36
        return button
    }()

    override func configureHierarchy() {
        view.addSubview(previewContainerView)
        view.addSubview(guideOverlay)
        view.addSubview(closeButton)
        view.addSubview(hintLabel)
        view.addSubview(shutterButton)
    }

    override func configureLayout() {
        previewContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(32)
        }

        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(closeButton.snp.bottom).offset(16)
            make.horizontalEdges.equalToSuperview().inset(32)
        }

        shutterButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
            make.size.equalTo(72)
        }

        // 어두운 배경이 화면 일부에만 걸리지 않도록, 가이드 오버레이는 항상 화면 전체를 덮는다.
        // 안내 문구/셔터 버튼과 사각형 구멍이 겹치지 않게 하는 여백은 viewDidLayoutSubviews에서
        // topContentInset/bottomContentInset으로 별도 지정한다.
        guideOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func configureView() {
        super.configureView()
        view.backgroundColor = .black
        // modalPresentationStyle은 present(_:) 호출 전, 프레젠팅 쪽에서 지정해야
        // 확실히 반영된다 (TravelAddViewController+TicketCapture.swift 참고).
    }

    override func configureBind() {
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewContainerView.bounds

        // 사각형 구멍이 안내 문구/셔터 버튼과 겹치지 않도록, 실제 배치된 프레임 기준으로 여백을 갱신한다.
        guideOverlay.topContentInset = hintLabel.frame.maxY + 20
        guideOverlay.bottomContentInset = view.bounds.height - shutterButton.frame.minY + 24
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        requestCameraAccessAndStart()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    // MARK: - Actions

    @objc private func didTapClose() {
        delegate?.ticketCameraDidCancel(self)
    }

    @objc private func didTapShutter() {
        triggerCapture()
    }

    /// 수동 셔터 탭과 자동 인식이 공유하는 진입점. "사진을 찍는" 게 아니라, 그 순간의
    /// 라이브 프레임을 그대로 잘라 쓴다 — 촬영 사운드/지연 없이 즉시 결과로 이어진다.
    private func triggerCapture() {
        latestPixelBufferLock.lock()
        let pixelBuffer = latestPixelBuffer
        latestPixelBufferLock.unlock()

        guard !isCapturing, let pixelBuffer else { return }
        isCapturing = true

        guard let rawImage = image(from: pixelBuffer) else {
            isCapturing = false
            return
        }

        let result = croppedToGuide(rawImage)
        delegate?.ticketCamera(self, didCapture: result)
    }

    // MARK: - Permission & session setup

    private func requestCameraAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeededAndStart()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureSessionIfNeededAndStart()
                    } else {
                        self.showCameraPermissionAlert()
                    }
                }
            }

        case .denied, .restricted:
            showCameraPermissionAlert()

        @unknown default:
            showCameraPermissionAlert()
        }
    }

    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "카메라 권한 필요",
            message: "사진을 촬영하려면 카메라 접근 권한이 필요합니다. '설정'으로 이동하여 권한을 허용해주세요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { [weak self] _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            guard let self else { return }
            self.delegate?.ticketCameraDidCancel(self)
        })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.delegate?.ticketCameraDidCancel(self)
        })
        present(alert, animated: true)
    }

    private func configureSessionIfNeededAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isSessionConfigured {
                self.configureSession()
                self.isSessionConfigured = true
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    /// AVCaptureSession/입출력 구성 — 세션 큐에서만 호출한다.
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addInput(input)

        // 별도의 "사진 촬영" 출력 없이, 인식/결과 모두 이 비디오 프레임 출력 하나로 처리한다.
        guard captureSession.canAddOutput(videoDataOutput) else {
            captureSession.commitConfiguration()
            return
        }
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: visionQueue)
        captureSession.addOutput(videoDataOutput)

        // 프리뷰와 프레임 좌표 기준이 같도록 세로로 고정한다 (앱 전체가 세로 전용).
        videoDataOutput.connection(with: .video)?.videoOrientation = .portrait

        captureSession.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            self?.attachPreviewLayer()
        }
    }

    private func attachPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = previewContainerView.bounds
        layer.connection?.videoOrientation = .portrait
        previewContainerView.layer.addSublayer(layer)
        previewLayer = layer
    }

    // MARK: - Frame → UIImage / crop

    private func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    /// 가이드 경계에 딱 붙어있던 글자가 살짝 잘리는 걸 막기 위해, 가이드 영역보다
    /// 이만큼(가이드 크기 대비 비율) 더 넉넉하게 잘라낸다.
    private static let cropPaddingFraction: CGFloat = 0.12

    private func croppedToGuide(_ rawImage: UIImage) -> UIImage {
        let image = Self.normalizedUpOrientation(rawImage)

        guard let previewLayer, let cgImage = image.cgImage else { return image }

        let guideRectInPreview = guideOverlay.convert(guideOverlay.guideRect, to: previewContainerView)
        let normalizedRect = previewLayer.metadataOutputRectConverted(fromLayerRect: guideRectInPreview)

        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let tightRect = CGRect(
            x: normalizedRect.origin.x * CGFloat(cgImage.width),
            y: normalizedRect.origin.y * CGFloat(cgImage.height),
            width: normalizedRect.size.width * CGFloat(cgImage.width),
            height: normalizedRect.size.height * CGFloat(cgImage.height)
        )

        let paddedRect = tightRect
            .insetBy(dx: -tightRect.width * Self.cropPaddingFraction, dy: -tightRect.height * Self.cropPaddingFraction)
            .integral
            .intersection(imageBounds)

        guard !paddedRect.isEmpty, let cropped = cgImage.cropping(to: paddedRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    /// UIImage의 EXIF 방향 메타데이터를 실제 픽셀에 반영해, 이후 CGImage 크롭 좌표 계산이
    /// 항상 "화면에 보이는 그대로"의 좌표계와 일치하도록 만든다.
    private static func normalizedUpOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (실시간 인식)

extension TicketCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 캡처 트리거(자동/수동)가 항상 "지금 화면"을 쓸 수 있도록 매 프레임 갱신한다.
        latestPixelBufferLock.lock()
        latestPixelBuffer = pixelBuffer
        latestPixelBufferLock.unlock()

        guard !isCapturing else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAnalysisDate) >= Self.analysisMinInterval else { return }
        lastAnalysisDate = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        // 1단계: 사각형(문서) 형태인지 확인. 일반 도형 인식(VNDetectRectanglesRequest)은
        // 인쇄된 글자/그림이 많은 실제 문서에서 잘 안 잡히는 경우가 많아, 문서 인식
        // 전용으로 학습된 이 요청을 사용한다.
        let documentRequest = VNDetectDocumentSegmentationRequest()
        try? handler.perform([documentRequest])

        let hasDocumentShape = (documentRequest.results ?? []).contains { $0.confidence >= 0.6 }

        guard hasDocumentShape else {
            handleAlignmentResult(false)
            return
        }

        // 2단계: 모양만으로는 책/카드/상자 같은 "비슷하게 생긴 물체"와 구분할 수 없으므로,
        // 실제로 읽을 수 있는 글자가 충분히 있는지 확인한다 (티켓이라면 도시명/날짜/편명 등
        // 텍스트가 많다).
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = false
        try? handler.perform([textRequest])

        let recognizedCharacterCount = (textRequest.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .reduce(0) { $0 + $1.count }

        handleAlignmentResult(recognizedCharacterCount >= Self.minimumRecognizedCharacterCount)
    }

    private func handleAlignmentResult(_ isAligned: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCapturing else { return }

            self.guideOverlay.setAligned(isAligned)

            if isAligned {
                self.alignedStreak += 1
                if self.alignedStreak >= Self.requiredAlignedStreak {
                    self.triggerCapture()
                }
            } else {
                self.alignedStreak = 0
            }
        }
    }
}
