//
//  TicketMaskPreviewViewController.swift
//  TravelLog
//
//  Created by Claude on 8/16/26.
//
//  TicketImageRedactor가 민감정보 후보를 가린 이미지를 사용자에게 보여주고,
//  "이대로 전송"을 눌러야만 Claude로 넘어가게 하는 최종 확인 단계.
//  자동 마스킹이 못 가린 부분이 한두 군데 남았다면, 다시 촬영하지 않고도
//  이미지 위를 손가락으로 문질러 직접 가릴 수 있다.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

protocol TicketMaskPreviewViewControllerDelegate: AnyObject {
    func ticketMaskPreview(_ controller: TicketMaskPreviewViewController, didConfirm image: UIImage)
    /// "다시 촬영" — 카메라 화면으로 돌아가 새로 찍는다.
    func ticketMaskPreviewDidRequestRetake(_ controller: TicketMaskPreviewViewController)
    /// 좌상단 X — 티켓 스캔 자체를 그만두고 원래 화면으로 나간다.
    func ticketMaskPreviewDidCancel(_ controller: TicketMaskPreviewViewController)
}

final class TicketMaskPreviewViewController: BaseViewController {
    weak var delegate: TicketMaskPreviewViewControllerDelegate?

    private let maskedImage: UIImage
    private let disposeBag = DisposeBag()

    /// 사용자가 직접 그린 마스킹 영역. imageView의 로컬 좌표계(포인트) 기준으로 저장하고,
    /// 최종 전송 직전에 이미지 픽셀 좌표계로 환산해 굽는다.
    private var manualMaskRects: [CGRect] = []
    private var manualMaskBoxViews: [UIView] = []
    private var activeDrawingBox: UIView?
    private var drawStartPoint: CGPoint = .zero

    init(maskedImage: UIImage) {
        self.maskedImage = maskedImage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        return view
    }()

    private let noticeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = """
        여권번호, 바코드 등 민감해 보이는 부분은 검게 가렸어요.
        아직 보이는 정보가 있다면 손가락으로 드래그해서 가려주세요. 많이 남았다면 다시 촬영해주세요.
        """
        return label
    }()

    private let undoButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "arrow.uturn.backward")
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.5)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        button.isHidden = true
        return button
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark")
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.5)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = config
        return button
    }()

    private let retakeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("다시 촬영", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 20
        return button
    }()

    private let confirmButton = PrimaryButton(title: "이대로 전송")

    private let buttonStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    // UIPanGestureRecognizer는 인식되기까지 최소 이동 거리(약 10pt)가 필요해서, 그
    // 시점의 위치를 시작점으로 쓰면 실제 터치 지점보다 드래그 방향으로 밀려서 잡힌다.
    // minimumPressDuration 0인 LongPress는 터치 즉시 .began이 발생해 정확한 지점부터 시작된다.
    private lazy var maskDrawGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleMaskDraw(_:)))
        gesture.minimumPressDuration = 0
        return gesture
    }()

    // MARK: - Base template

    override func configureHierarchy() {
        view.addSubview(imageView)
        view.addSubview(undoButton)
        view.addSubview(closeButton)
        view.addSubview(noticeLabel)
        buttonStackView.addArrangedSubview(retakeButton)
        buttonStackView.addArrangedSubview(confirmButton)
        view.addSubview(buttonStackView)
    }

    override func configureLayout() {
        imageView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.horizontalEdges.equalToSuperview().inset(16)
            make.bottom.equalTo(noticeLabel.snp.top).offset(-16)
        }

        closeButton.snp.makeConstraints { make in
            make.top.equalTo(imageView).offset(8)
            make.leading.equalTo(imageView).offset(8)
            make.size.equalTo(36)
        }

        undoButton.snp.makeConstraints { make in
            make.top.equalTo(imageView).offset(8)
            make.trailing.equalTo(imageView).offset(-8)
            make.size.equalTo(36)
        }

        noticeLabel.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(24)
            make.bottom.equalTo(buttonStackView.snp.top).offset(-16)
        }

        buttonStackView.snp.makeConstraints { make in
            make.horizontalEdges.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(48)
        }
    }

    override func configureView() {
        view.backgroundColor = .black
        imageView.image = maskedImage
        imageView.addGestureRecognizer(maskDrawGesture)
    }

    override func configureBind() {
        retakeButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.delegate?.ticketMaskPreviewDidRequestRetake(owner)
            }
            .disposed(by: disposeBag)

        closeButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.delegate?.ticketMaskPreviewDidCancel(owner)
            }
            .disposed(by: disposeBag)

        confirmButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.delegate?.ticketMaskPreview(owner, didConfirm: owner.imageWithManualMasksApplied())
            }
            .disposed(by: disposeBag)

        undoButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.undoLastManualMask()
            }
            .disposed(by: disposeBag)
    }

    // MARK: - 직접 마스킹(손가락으로 문지르기)

    @objc private func handleMaskDraw(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: imageView)

        switch gesture.state {
        case .began:
            drawStartPoint = location
            let box = UIView()
            box.backgroundColor = .black
            box.isUserInteractionEnabled = false
            imageView.addSubview(box)
            activeDrawingBox = box

        case .changed:
            guard let box = activeDrawingBox else { return }
            box.frame = CGRect(
                x: min(drawStartPoint.x, location.x),
                y: min(drawStartPoint.y, location.y),
                width: abs(location.x - drawStartPoint.x),
                height: abs(location.y - drawStartPoint.y)
            )

        case .ended, .cancelled:
            guard let box = activeDrawingBox else { return }
            // 실수로 살짝 스친 정도(탭에 가까운 드래그)는 무시한다.
            if box.frame.width < 8 || box.frame.height < 8 {
                box.removeFromSuperview()
            } else {
                manualMaskRects.append(box.frame)
                manualMaskBoxViews.append(box)
                undoButton.isHidden = false
            }
            activeDrawingBox = nil

        default:
            break
        }
    }

    private func undoLastManualMask() {
        guard let lastBox = manualMaskBoxViews.popLast() else { return }
        lastBox.removeFromSuperview()
        manualMaskRects.removeLast()
        undoButton.isHidden = manualMaskBoxViews.isEmpty
    }

    private func imageWithManualMasksApplied() -> UIImage {
        guard !manualMaskRects.isEmpty else { return maskedImage }

        let displayRect = Self.imageDisplayRect(for: maskedImage.size, in: imageView.bounds.size)
        let pixelRects = manualMaskRects.map { viewRect in
            Self.convert(viewRect, from: displayRect, to: maskedImage.size)
        }
        return TicketImageRedactor.applyManualMasks(pixelRects, to: maskedImage)
    }

    /// contentMode == .scaleAspectFit일 때, imageView 안에서 이미지가 실제로 그려지는 영역(레터박스 제외).
    private static func imageDisplayRect(for imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        if imageAspect > viewAspect {
            let displayWidth = viewSize.width
            let displayHeight = displayWidth / imageAspect
            return CGRect(x: 0, y: (viewSize.height - displayHeight) / 2, width: displayWidth, height: displayHeight)
        } else {
            let displayHeight = viewSize.height
            let displayWidth = displayHeight * imageAspect
            return CGRect(x: (viewSize.width - displayWidth) / 2, y: 0, width: displayWidth, height: displayHeight)
        }
    }

    /// imageView 로컬 좌표계의 사각형을 실제 이미지 픽셀 좌표계로 환산한다.
    private static func convert(_ viewRect: CGRect, from displayRect: CGRect, to imageSize: CGSize) -> CGRect {
        guard displayRect.width > 0, displayRect.height > 0 else { return .zero }

        let scaleX = imageSize.width / displayRect.width
        let scaleY = imageSize.height / displayRect.height
        let rect = CGRect(
            x: (viewRect.minX - displayRect.minX) * scaleX,
            y: (viewRect.minY - displayRect.minY) * scaleY,
            width: viewRect.width * scaleX,
            height: viewRect.height * scaleY
        )
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }
}
