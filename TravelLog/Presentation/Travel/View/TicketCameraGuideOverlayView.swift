//
//  TicketCameraGuideOverlayView.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//
//  카메라 프리뷰 위에 어두운 배경 + 직사각형(티켓/카드 비율) 구멍을 그려, 티켓을 어디에
//  맞춰야 하는지 안내한다. 인식 상태에 따라 테두리가 흰색 ↔ 초록색으로 바뀐다.
//
//  이 뷰는 항상 화면 전체(edges.equalToSuperview())에 맞춰 배치해서, 어두운 배경이
//  중간 영역에만 걸리지 않고 화면 전체를 덮도록 한다. 대신 상단 안내 문구/하단 셔터
//  버튼과 사각형 구멍이 겹치지 않도록, topContentInset/bottomContentInset으로
//  구멍이 놓일 수 있는 세로 영역만 별도로 제한한다.
//

import UIKit

final class TicketCameraGuideOverlayView: UIView {

    /// 티켓/카드 형태에 가까운 가로:세로 비율 (신용카드 비율과 유사한, 가로가 더 긴 직사각형)
    static let guideAspectRatio: CGFloat = 1.6

    private let horizontalInset: CGFloat = 20

    /// 상단 안내 문구 아래로 비워둘 여백 (이 안에는 사각형 구멍이 그려지지 않는다)
    var topContentInset: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    /// 하단 셔터 버튼 위로 비워둘 여백
    var bottomContentInset: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    private let dimLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.fillRule = .evenOdd
        return layer
    }()

    private let borderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = 3
        layer.fillColor = UIColor.clear.cgColor
        return layer
    }()

    /// 실제로 잘라낼 직사각형 영역 (이 뷰 자신의 좌표계 기준)
    private(set) var guideRect: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(dimLayer)
        layer.addSublayer(borderLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let availableWidth = bounds.width - horizontalInset * 2
        let availableHeight = max(bounds.height - topContentInset - bottomContentInset, 0)

        var width = availableWidth
        var height = width / Self.guideAspectRatio

        if height > availableHeight {
            height = availableHeight
            width = height * Self.guideAspectRatio
        }

        guideRect = CGRect(
            x: (bounds.width - width) / 2,
            y: topContentInset + (availableHeight - height) / 2,
            width: width,
            height: height
        )

        // dimLayer는 항상 이 뷰의 전체 bounds(=화면 전체)를 덮고, 사각형 구멍만 뚫는다.
        let outerPath = UIBezierPath(rect: bounds)
        let innerPath = UIBezierPath(roundedRect: guideRect, cornerRadius: 16)
        outerPath.append(innerPath)
        dimLayer.path = outerPath.cgPath

        borderLayer.path = UIBezierPath(roundedRect: guideRect, cornerRadius: 16).cgPath
    }

    /// 티켓이 사각형 안에 잘 인식되고 있는지에 따라 테두리 색을 갱신한다.
    func setAligned(_ isAligned: Bool) {
        let color = (isAligned ? UIColor.systemGreen : UIColor.white).cgColor
        guard borderLayer.strokeColor != color else { return }
        borderLayer.strokeColor = color
    }
}
