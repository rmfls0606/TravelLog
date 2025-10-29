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
    
    private let emptyContainerView = UIView()
    private let emptyView = CustomEmptyView()
    
    private let addBlockContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private let addBar = UIStackView()
    private let blockTitle: UILabel = {
        let label = UILabel()
        label.text = "블록 추가하기"
        label.textColor = .black
        label.font = .systemFont(ofSize: 16, weight: .bold)
        return label
    }()
    
    private let textButton = UIButton(configuration: .filled())
    private let linkButton = UIButton(configuration: .filled())
    private let photoButton = UIButton(configuration: .filled())
    
    private let saveButton = UIButton(configuration: .filled())
    
    private let viewModel: JournalAddViewModel
    private let disposeBag = DisposeBag()
    private let saveTrigger = PublishRelay<[JournalAddViewModel.JournalBlockData]>()
    
    init(viewModel: JournalAddViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Hierarchy
    override func configureHierarchy() {
        view.addSubviews(scrollView, addBlockContainer, saveButton)
        scrollView.addSubview(contentStack)
        addBar.addArrangedSubview(textButton)
        addBar.addArrangedSubview(linkButton)
        addBar.addArrangedSubview(photoButton)
        addBlockContainer.addSubview(blockTitle)
        addBlockContainer.addSubview(addBar)
        // empty container
        view.insertSubview(emptyContainerView, belowSubview: addBar)
        emptyContainerView.addSubview(emptyView)
    }
    
    // MARK: - Layout
    override func configureLayout() {
        scrollView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(addBar.snp.top)
        }

        contentStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide).inset(16)
            $0.width.equalTo(scrollView.frameLayoutGuide).offset(-32)
        }

        emptyContainerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.bottom.equalTo(addBar.snp.top)
            $0.horizontalEdges.equalToSuperview().inset(16)
        }

        emptyView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.lessThanOrEqualToSuperview().inset(16)
        }

        addBlockContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(saveButton.snp.top).offset(-12)
        }
        
        addBar.snp.makeConstraints {
            $0.top.equalTo(blockTitle.snp.bottom).offset(16)
            $0.horizontalEdges.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().inset(16)
        }
        
        blockTitle.snp.makeConstraints { make in
            make.top.horizontalEdges.equalToSuperview().inset(16)
        }

        saveButton.snp.makeConstraints {
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.height.equalTo(52)
        }
    }
    
    // MARK: - View
    override func configureView() {
        view.backgroundColor = .systemGroupedBackground
        title = "추억 기록하기"
        
        scrollView.alwaysBounceVertical = true
        contentStack.axis = .vertical
        contentStack.spacing = 16
        
        // EmptyView
        emptyView.configure(
            icon: UIImage(systemName: "folder.fill"),
            iconTint: .white,
            gradientStyle: .bluePurple,
            title: "첫 번째 블록을 추가해보세요",
            subtitle: "아래 버튼을 눌러 추억을 기록할 수 있어요",
            buttonTitle: nil
        )
        
        addBlockContainer.layer.cornerRadius = 12
        addBar.axis = .horizontal
        addBar.distribution = .fillEqually
        addBar.spacing = 12
        
        configureButtons()
        configureKeyboardDismissGesture()
    }
    
    // MARK: - 버튼 설정 (cornerRadius 정상 적용)
    private func configureButtons() {
        // 텍스트 버튼
        var textConfig = UIButton.Configuration.filled()
        textConfig.baseForegroundColor = .white
        textConfig.image = UIImage(
            systemName: "pencil.line",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        )
        textConfig.imagePadding = 8
        textConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        textConfig.attributedTitle = AttributedString(
            "텍스트",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .semibold)])
        )
        
        // UIBackgroundConfiguration.clear() 사용
        var textBg = UIBackgroundConfiguration.clear()
        textBg.cornerRadius = 12
        textBg.backgroundColor = UIColor.systemBlue
        textConfig.background = textBg
        
        textButton.configuration = textConfig
        textButton.clipsToBounds = true
        
        //링크 버튼
        var linkConfig = UIButton.Configuration.filled()
        linkConfig.baseForegroundColor = .white
        linkConfig.image = UIImage(
            systemName: "link",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        )
        linkConfig.imagePadding = 8
        linkConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        linkConfig.attributedTitle = AttributedString(
            "링크",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .semibold)])
        )
        
        // UIBackgroundConfiguration.clear() 사용
        var linkBg = UIBackgroundConfiguration.clear()
        linkBg.cornerRadius = 12
        linkBg.backgroundColor = UIColor.systemGreen
        linkConfig.background = linkBg
        
        linkButton.configuration = linkConfig
        linkButton.clipsToBounds = true
        
        //포토 버튼
        var photoConfig = UIButton.Configuration.filled()
        photoConfig.baseForegroundColor = .white
        photoConfig.image = UIImage(
            systemName: "camera",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        )
        photoConfig.imagePadding = 8
        photoConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        photoConfig.attributedTitle = AttributedString(
            "사진",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .semibold)])
        )
        
        // UIBackgroundConfiguration.clear() 사용
        var photoBg = UIBackgroundConfiguration.clear()
        photoBg.cornerRadius = 12
        photoBg.backgroundColor = UIColor.systemPink
        photoConfig.background = photoBg
        
        photoButton.configuration = photoConfig
        photoButton.clipsToBounds = true
        
        // 저장 버튼
        var saveConfig = UIButton.Configuration.filled()
        saveConfig.baseForegroundColor = .white
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        saveConfig.attributedTitle = AttributedString(
            "저장하기",
            attributes: AttributeContainer([.font: UIFont.boldSystemFont(ofSize: 16)])
        )
        
        // clear()로 초기화 후 설정
        var saveBg = UIBackgroundConfiguration.clear()
        saveBg.cornerRadius = 12
        saveBg.backgroundColor = .systemGray4
        saveConfig.background = saveBg
        
        saveButton.configuration = saveConfig
        saveButton.clipsToBounds = true
        saveButton.isEnabled = false
    }
    
    private func configureKeyboardDismissGesture() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        tapGesture.rx.event
            .bind(with: self) { owner, _ in owner.view.endEditing(true) }
            .disposed(by: disposeBag)
    }
    
    // MARK: - Binding
    override func configureBind() {
        textButton.rx.tap
            .bind(with: self) { owner, _ in owner.addTextBlock() }
            .disposed(by: disposeBag)
        
        linkButton.rx.tap
            .bind(with: self) { owner, _ in
                owner.addLinkBlock()
            }
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .map { [weak self] _ -> [JournalAddViewModel.JournalBlockData] in
                guard let self = self else { return [] }
                return self.contentStack.arrangedSubviews.compactMap {
                    if let textBlock = $0 as? JournalTextBlockView, !textBlock.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let content = textBlock.textContent
                        return JournalAddViewModel.JournalBlockData(type: .text, text: content, linkURL: nil)
                    } else if let linkBlock = $0 as? JournalLinkBlockView, let content = linkBlock.textContent, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return JournalAddViewModel.JournalBlockData(type: .link, text: nil, linkURL: content)
                    }
                    return nil
                }
            }
            .bind(to: saveTrigger)
            .disposed(by: disposeBag)
        
        let input = JournalAddViewModel.Input(saveTapped: saveTrigger.asObservable())
        let output = viewModel.transform(input: input)
        
        output.saveCompleted
            .emit(with: self) { owner, _ in
                owner.navigationController?.popViewController(animated: true)
            }
            .disposed(by: disposeBag)
    }
    
    private func updateSaveButton(enabled: Bool) {
        saveButton.isEnabled = enabled
        if var config = saveButton.configuration {
            var bg = config.background
            bg.backgroundColor = enabled ? .systemBlue : .systemGray4
            bg.cornerRadius = 12
            config.background = bg
            saveButton.configuration = config
        }
    }

    // MARK: - 블록 추가
    private func addTextBlock() {
        emptyContainerView.isHidden = true
        updateSaveButton(enabled: true)
        
        let card = JournalTextBlockView()
        contentStack.addArrangedSubview(card)
        card.snp.makeConstraints { $0.height.greaterThanOrEqualTo(120) }
        
        card.removeTapped
            .bind(with: self) { owner, _ in
                UIView.animate(withDuration: 0.25) {
                    card.alpha = 0
                } completion: { _ in
                    owner.contentStack.removeArrangedSubview(card)
                    card.removeFromSuperview()
                    
                    if owner.contentStack.arrangedSubviews.isEmpty {
                        owner.emptyContainerView.isHidden = false
                        owner.updateSaveButton(enabled: false)
                    }
                }
            }
            .disposed(by: card.disposeBag)
    }
    
    private func addLinkBlock() {
        emptyContainerView.isHidden = true
        updateSaveButton(enabled: true)
        
        let card = JournalLinkBlockView()
        contentStack.addArrangedSubview(card)
        
        card.removeTapped
            .bind(with: self) { owner, _ in
                UIView.animate(withDuration: 0.25) {
                    card.alpha = 0
                } completion: { _ in
                    owner.contentStack.removeArrangedSubview(card)
                    card.removeFromSuperview()
                    
                    if owner.contentStack.arrangedSubviews.isEmpty {
                        owner.emptyContainerView.isHidden = false
                        owner.updateSaveButton(enabled: false)
                    }
                }
            }
            .disposed(by: card.disposeBag)
    }
}
