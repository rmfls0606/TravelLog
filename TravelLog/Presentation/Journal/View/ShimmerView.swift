//
//  ShimmerView.swift
//  TravelLog
//
//  Created by 이상민 on 11/5/25.
//

import UIKit
import SnapKit

final class ShimmerView: UIView {
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray3.cgColor,
            UIColor.systemGray5.cgColor
        ]
        layer.locations = [0.0, 0.5, 1.0]
        layer.startPoint = CGPoint(x: 0.0, y: 0.5)
        layer.endPoint = CGPoint(x: 1.0, y: 0.5)
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
    }
    
    private func configureHierarchy(){
        layer.addSublayer(gradientLayer)
    }
    
    //ShimmerView 애니메이션 시작
    func startShimmering(){
        isHidden = false
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.25
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmerAnimation")
    }
    
    //ShimmerView 애니메이션 중지
    func stopShimmering(){
        isHidden = true
        gradientLayer.removeAnimation(forKey: "shimmerAnimation")
    }
}
