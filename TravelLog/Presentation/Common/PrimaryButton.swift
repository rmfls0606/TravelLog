//
//  PrimaryButton.swift
//  TravelLog
//
//  Created by 이상민 on 10/1/25.
//

import UIKit

final class PrimaryButton: UIButton {
    init(title: String){
        super.init(frame: .zero)
        setupStyle()
        setTitle(title, for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupStyle(){
        setTitleColor(.white, for: .normal)
        titleLabel?.font = .boldSystemFont(ofSize: 16)
        layer.cornerRadius = 20
        clipsToBounds = true
        backgroundColor = .systemBlue
    }
}
