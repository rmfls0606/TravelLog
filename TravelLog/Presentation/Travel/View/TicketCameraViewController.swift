//
//  TicketCameraViewController.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//
//  티켓 스캔 전용 커스텀 카메라 화면. 별도의 "사진 촬영" 단계 없이, 화면 중앙의
//  직사각형(티켓/카드 비율) 가이드 안에 티켓이 들어오면 실시간으로 인식해 테두리가
//  초록색으로 바뀌고, 그 순간의 화면(라이브 프레임)을 그대로 잘라서 결과로 전달한다.
//  (인식이 잘 안 되는 티켓(구겨짐, 저조도 등)을 대비해 하단의 "앨범에서 가져오기"
//  버튼으로 언제든 앨범 선택으로 전환할 수 있다.)
//
//  인식 판정은 세 단계로 이루어진다:
//   1) 문서 인식(VNDetectDocumentSegmentationRequest) — 사각형 문서 형태인지 확인
//   2) 가이드 포함 여부 — 감지된 문서 경계가 화면의 가이드 사각형(+크롭 여백) 안에
//      완전히 들어와 있는지 확인 (티켓이 가이드보다 커서 일부가 밖으로 삐져나온 채로
//      캡처되면, 크롭 시 그 부분이 잘려나가 정보 누락으로 이어지기 때문)
//   3) 텍스트 인식(VNRecognizeTextRequest) — 그 사각형 안에 읽을 수 있는 글자가
//      충분히 있는지 확인 (책, 카드, 상자 등 "모양만 비슷한" 물체를 걸러내기 위함)
//  세 조건을 모두 만족해야 "티켓처럼 보인다"고 판단한다.
//

import UIKit
import AVFoundation
import Vision
import SnapKit

protocol TicketCameraViewControllerDelegate: AnyObject {
    func ticketCamera(_ controller: TicketCameraViewController, didCapture image: UIImage)
    func ticketCameraDidCancel(_ controller: TicketCameraViewController)
    func ticketCameraDidTapPhotoLibrary(_ controller: TicketCameraViewController)
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

    private let photoLibraryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("앨범에서 가져오기", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        button.backgroundColor = .white
        button.layer.cornerRadius = 15
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return button
    }()

    override func configureHierarchy() {
        view.addSubview(previewContainerView)
        view.addSubview(guideOverlay)
        view.addSubview(closeButton)
        view.addSubview(hintLabel)
        view.addSubview(photoLibraryButton)
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

        photoLibraryButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(24)
        }

        // 어두운 배경이 화면 일부에만 걸리지 않도록, 가이드 오버레이는 항상 화면 전체를 덮는다.
        // 안내 문구/앨범 버튼과 사각형 구멍이 겹치지 않게 하는 여백은 viewDidLayoutSubviews에서
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
        photoLibraryButton.addTarget(self, action: #selector(didTapPhotoLibrary), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewContainerView.bounds

        // 사각형 구멍이 안내 문구/앨범 버튼과 겹치지 않도록, 실제 배치된 프레임 기준으로 여백을 갱신한다.
        guideOverlay.topContentInset = hintLabel.frame.maxY + 20
        guideOverlay.bottomContentInset = view.bounds.height - photoLibraryButton.frame.minY + 24
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

    @objc private func didTapPhotoLibrary() {
        delegate?.ticketCameraDidTapPhotoLibrary(self)
    }

    /// 자동 인식(5프레임 연속 정렬) 시 호출되는 캡처 진입점. "사진을 찍는" 게 아니라,
    /// 그 순간의 라이브 프레임을 그대로 잘라 쓴다 — 촬영 사운드/지연 없이 즉시 결과로 이어진다.
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

    /// 가이드 사각형을, 실제 픽셀 버퍼(bufferWidth × bufferHeight) 기준 정규화 좌표계
    /// (0...1, 좌상단 원점)로 변환한다. 크롭(픽셀 좌표 계산)과 실시간 가이드 포함 여부
    /// 판정이 이 좌표를 함께 사용한다.
    ///
    /// `AVCaptureVideoPreviewLayer.metadataOutputRectConverted(fromLayerRect:)`를 쓰면 될
    /// 것 같지만, 그 API는 previewLayer 자신의 connection(videoDataOutput의 connection과는
    /// 별개)의 videoOrientation 상태에 의존한다. 실측 결과 그 connection이 안정적으로
    /// portrait로 맞춰지지 않아(강제로 재설정해도 결과가 그대로) 가이드 사각형이 90도
    /// 돌아간 채로 계산되는 문제가 있었다. 그래서 그 API를 쓰지 않고, previewLayer의
    /// videoGravity(.resizeAspectFill)가 하는 크롭을 직접 재현한다 — 뷰 크기와 실제 버퍼
    /// 크기만 있으면 계산할 수 있어 connection 상태와 무관하게 항상 정확하다.
    private func normalizedGuideRect(bufferWidth: Int, bufferHeight: Int) -> CGRect? {
        guard bufferWidth > 0, bufferHeight > 0 else { return nil }

        let viewSize = previewContainerView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let guideRectInPreview = guideOverlay.convert(guideOverlay.guideRect, to: previewContainerView)
        let bufferSize = CGSize(width: bufferWidth, height: bufferHeight)

        // resizeAspectFill: 버퍼를 뷰 전체가 덮이도록 확대하고, 넘치는 부분을 가운데
        // 기준으로 잘라낸다. scale은 그 확대 배율, offset은 잘려나간 여백(뷰 좌표계 기준).
        let scale = max(viewSize.width / bufferSize.width, viewSize.height / bufferSize.height)
        let offsetX = (bufferSize.width * scale - viewSize.width) / 2
        let offsetY = (bufferSize.height * scale - viewSize.height) / 2

        let bufferPointRect = CGRect(
            x: (guideRectInPreview.origin.x + offsetX) / scale,
            y: (guideRectInPreview.origin.y + offsetY) / scale,
            width: guideRectInPreview.width / scale,
            height: guideRectInPreview.height / scale
        )

        return CGRect(
            x: bufferPointRect.origin.x / bufferSize.width,
            y: bufferPointRect.origin.y / bufferSize.height,
            width: bufferPointRect.width / bufferSize.width,
            height: bufferPointRect.height / bufferSize.height
        )
    }

    private func croppedToGuide(_ rawImage: UIImage) -> UIImage {
        let image = Self.normalizedUpOrientation(rawImage)

        guard
            let cgImage = image.cgImage,
            let normalizedRect = normalizedGuideRect(bufferWidth: cgImage.width, bufferHeight: cgImage.height)
        else { return image }

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

        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        // 1단계: 사각형(문서) 형태인지 확인. 일반 도형 인식(VNDetectRectanglesRequest)은
        // 인쇄된 글자/그림이 많은 실제 문서에서 잘 안 잡히는 경우가 많아, 문서 인식
        // 전용으로 학습된 이 요청을 사용한다.
        let documentRequest = VNDetectDocumentSegmentationRequest()
        try? handler.perform([documentRequest])

        let documentBoundingBoxes = (documentRequest.results ?? [])
            .filter { $0.confidence >= 0.6 }
            .map(\.boundingBox)

        guard !documentBoundingBoxes.isEmpty else {
            handleAlignmentResult(
                hasEnoughText: false,
                documentBoundingBoxes: [],
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
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
        let hasEnoughText = recognizedCharacterCount >= Self.minimumRecognizedCharacterCount

        handleAlignmentResult(
            hasEnoughText: hasEnoughText,
            documentBoundingBoxes: documentBoundingBoxes,
            bufferWidth: bufferWidth,
            bufferHeight: bufferHeight
        )
    }

    /// 문서 인식/텍스트 인식은 백그라운드 큐에서 끝나지만, 가이드 사각형 포함 여부는
    /// previewContainerView/guideOverlay 같은 UIKit 값을 읽어야 해서 메인 스레드에서만
    /// 계산한다.
    private func handleAlignmentResult(
        hasEnoughText: Bool,
        documentBoundingBoxes: [CGRect],
        bufferWidth: Int,
        bufferHeight: Int
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCapturing else { return }

            let isDocumentFullyInGuide = self.isDocumentFullyInsideGuide(
                among: documentBoundingBoxes,
                bufferWidth: bufferWidth,
                bufferHeight: bufferHeight
            )
            let isAligned = hasEnoughText && isDocumentFullyInGuide

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

    /// 감지된 문서 사각형 중 하나라도 "실제로 크롭될 영역(가이드 + 크롭 여백)" 안에
    /// 완전히 들어와 있으면 true. 티켓이 가이드보다 크거나 밖으로 삐져나온 채로는
    /// 통과하지 못하게 막아, 크롭 시 정보가 잘려나가는 것을 방지한다.
    private func isDocumentFullyInsideGuide(
        among documentBoundingBoxes: [CGRect],
        bufferWidth: Int,
        bufferHeight: Int
    ) -> Bool {
        guard
            !documentBoundingBoxes.isEmpty,
            let normalizedGuideRect = normalizedGuideRect(bufferWidth: bufferWidth, bufferHeight: bufferHeight)
        else { return false }

        let paddedGuideRect = normalizedGuideRect.insetBy(
            dx: -normalizedGuideRect.width * Self.cropPaddingFraction,
            dy: -normalizedGuideRect.height * Self.cropPaddingFraction
        )

        // normalizedGuideRect()는 CGImage 픽셀 좌표계와 맞춘 좌상단 원점(y 아래로 증가)
        // 기준이지만, Vision이 반환하는 boundingBox는 좌하단 원점(y 위로 증가)이라 같은
        // 사각형을 가리키려면 y축을 뒤집어야 한다.
        let paddedGuideRectInVisionSpace = CGRect(
            x: paddedGuideRect.origin.x,
            y: 1 - paddedGuideRect.origin.y - paddedGuideRect.height,
            width: paddedGuideRect.width,
            height: paddedGuideRect.height
        )

        return documentBoundingBoxes.contains { paddedGuideRectInVisionSpace.contains($0) }
    }
}
