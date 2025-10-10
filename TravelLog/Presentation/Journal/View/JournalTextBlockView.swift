//
//  JournalTextBlockView.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class JournalTextBlockView: UIView {
    
    // MARK: - UI
    private let headerStack = UIStackView()
    private let typeIcon = UIImageView(image: UIImage(systemName: "pencil"))
    private let typeLabel = UILabel()
    private let timeLabel = UILabel()
    private let removeButton = UIButton(type: .system)
    
    private let textContainer = UIView()
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    
    // MARK: - Rx
    let disposeBag = DisposeBag()
    let textChanged = PublishRelay<String>()
    let removeTapped = PublishRelay<Void>()
    
    private var lastSentText: String = ""  // 중복 방지용 캐시

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        configureAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupView() {
        addSubview(headerStack)
        addSubview(textContainer)
        textContainer.addSubview(textView)
        textContainer.addSubview(placeholderLabel)
        
        headerStack.addArrangedSubview(typeIcon)
        headerStack.addArrangedSubview(typeLabel)
        headerStack.addArrangedSubview(UIView()) // spacer
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(removeButton)
        
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 6
    }
    
    private func setupLayout() {
        headerStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        
        textContainer.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(10)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
            $0.height.greaterThanOrEqualTo(120)
        }
        
        textView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(12)
        }
        
        placeholderLabel.snp.makeConstraints {
            $0.top.equalTo(textView).offset(6)
            $0.leading.equalTo(textView).offset(8)
        }
    }
    
    private func configureAppearance() {
        // 카드 자체
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
        
        // 헤더
        typeIcon.tintColor = .systemBlue
        typeLabel.text = "텍스트"
        typeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        typeLabel.textColor = .systemBlue
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        timeLabel.text = formatter.string(from: Date())
        timeLabel.font = .systemFont(ofSize: 12)
        timeLabel.textColor = .gray
        
        removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        removeButton.tintColor = .systemGray3
        
        // 입력 영역
        textContainer.backgroundColor = .systemGray6
        textContainer.layer.cornerRadius = 12
        
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        
        placeholderLabel.text = "내용을 입력하세요"
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .systemGray3
        
        // Rx 바인딩
        textView.rx.text.orEmpty
                    .map { text -> String in
                        // ⚠️ 엔터·공백만 입력한 경우는 빈 문자열로 처리
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return ""
                        }
                        return text
                    }
                    .distinctUntilChanged()
                    .bind(with: self) { owner, text in
                        // ✅ placeholder 표시/숨김
                        owner.placeholderLabel.isHidden = !text.isEmpty
                        
                        // ✅ 텍스트 변경 이벤트 전달
                        owner.textChanged.accept(text)
                    }
                    .disposed(by: disposeBag)
        
        removeButton.rx.tap
            .bind(to: removeTapped)
            .disposed(by: disposeBag)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if text == "\n" {
                // 엔터 입력 → 단순 개행 허용, 저장 trigger 없음
                return true
            }
            return true
        }

        // ✅ 텍스트가 바뀔 때마다 (엔터 제외) ViewModel로 전달
        func textViewDidChange(_ textView: UITextView) {
            let current = textView.text ?? ""
            // 🔸 1. 줄바꿈만 있는 변경은 무시
            guard !current.hasSuffix("\n") else { return }
            // 🔸 2. 중복 저장 방지
            guard current != lastSentText else { return }

            lastSentText = current
            textChanged.accept(current)
        }
}
