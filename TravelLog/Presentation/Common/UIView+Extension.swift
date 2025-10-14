//
//  UIView+Extension.swift
//  TravelLog
//
//  Created by 이상민 on 10/14/25.
//

import UIKit

extension UIView{
    
    //UIView 전체에 그라데이션을 적용
    func applyGradient(style: GradientStyle,
                       start: CGPoint = CGPoint(x: 0, y: 0.5),
                       end: CGPoint = CGPoint(x: 1, y: 0.5),
                       cornerRadius: CGFloat? = nil
    ){
        //기존 gradient layer 제거(중첩 방지)
        layer.sublayers?
            .filter{ $0 is CAGradientLayer }
            .forEach{ $0.removeFromSuperlayer() }
        
        let gradient = CAGradientLayer()
        gradient.colors = style.colors.map { $0.cgColor }
        gradient.startPoint = start
        gradient.endPoint = end
        gradient.frame = bounds
        
        if let cornerRadius{
            gradient.cornerRadius = cornerRadius
        }else if layer.cornerRadius > 0 {
            gradient.cornerRadius = layer.cornerRadius
        }
        
        layer.insertSublayer(gradient, at: 0)
    }
}
