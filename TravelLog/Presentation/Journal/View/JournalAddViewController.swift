//
//  JournalAddViewController.swift
//  TravelLog
//
//  Created by 이상민 on 10/10/25.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

final class JournalAddViewController: BaseViewController {
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let emptyView = UIView()
    private let emptyLabel = UILabel()
    private let addBar = UIStackView()
    private let textButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    
    private let viewModel: JournalAddViewModel
    private let disposeBag = DisposeBag()
    
    // ✅ ViewModel로 보낼 save 이벤트용 Relay
    private let saveTrigger = PublishRelay<[String]>()
    
    init(viewModel: JournalAddViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    override func configureHierarchy() {
        view.addSubviews(scrollView, addBar, saveButton)
        scrollView.addSubview(contentStack)
        addBar.addArrangedSubview(textButton)
        contentStack.addArrangedSubview(emptyView)
        emptyView.addSubview(emptyLabel)
    }
    
    override func configureLayout() {
        scrollView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(addBar.snp.top)
        }
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(16)
            $0.width.equalTo(scrollView.snp.width).offset(-32)
        }
        emptyView.snp.makeConstraints { $0.height.equalTo(220) }
        emptyLabel.snp.makeConstraints { $0.center.equalToSuperview() }
        addBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(saveButton.snp.top).offset(-12)
            $0.height.equalTo(60)
        }
        saveButton.snp.makeConstraints {
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.height.equalTo(52)
        }
    }
    
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        title = "추억 추가"
        
        scrollView.alwaysBounceVertical = true
        contentStack.axis = .vertical
        contentStack.spacing = 16
        
        emptyLabel.text = "✏️ 아래 버튼을 눌러 블록을 추가하세요"
        emptyLabel.textColor = .systemGray
        
        addBar.axis = .horizontal
        addBar.distribution = .fillEqually
        addBar.spacing = 12
        
        textButton.setTitle("✏️ 텍스트", for: .normal)
        textButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        textButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        textButton.layer.cornerRadius = 12
        textButton.tintColor = .systemBlue
        
        saveButton.setTitle("저장하기", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        saveButton.backgroundColor = .systemGray4
        saveButton.layer.cornerRadius = 12
        saveButton.isEnabled = false
    }
    
    override func configureBind() {
        // ✅ 블록 추가
        textButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.addTextBlock()
            }
            .disposed(by: disposeBag)
        
        // ✅ 저장 버튼 탭 시 현재 블록들의 텍스트 전부 수집
        saveButton.rx.tap
            .map { [weak self] _ -> [String] in
                guard let self = self else { return [] }
                return self.contentStack.arrangedSubviews
                    .compactMap { ($0 as? JournalTextBlockView)?.textContent } // ✅ 변경
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            .bind(to: saveTrigger)
            .disposed(by: disposeBag)
        
        // ✅ ViewModel transform
        let input = JournalAddViewModel.Input(saveTapped: saveTrigger.asObservable())
        let output = viewModel.transform(input: input)
        
        // ✅ 저장 완료 → 이전 화면으로 이동
        output.saveCompleted
            .emit(with: self) { owner, _ in
                print("✅ 저장 완료 — 이전 화면으로 이동")
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
    }
    
    private func addTextBlock() {
        emptyView.isHidden = true
        saveButton.isEnabled = true
        saveButton.backgroundColor = .systemBlue
        
        let card = JournalTextBlockView()
        contentStack.addArrangedSubview(card)
        card.snp.makeConstraints { $0.height.greaterThanOrEqualTo(120) }
        
        // ❌ index 없이: 단순히 UI에서 제거/추가
        card.removeTapped
            .bind(with: self) { owner, _ in
                UIView.animate(withDuration: 0.25) {
                    card.alpha = 0
                } completion: { _ in
                    owner.contentStack.removeArrangedSubview(card)
                    card.removeFromSuperview()
                    
                    let remaining = owner.contentStack.arrangedSubviews.compactMap { $0 as? JournalTextBlockView }
                    if remaining.isEmpty {
                        owner.emptyView.isHidden = false
                        owner.saveButton.isEnabled = false
                        owner.saveButton.backgroundColor = .systemGray4
                    }
                }
            }
            .disposed(by: card.disposeBag)
    }
}
