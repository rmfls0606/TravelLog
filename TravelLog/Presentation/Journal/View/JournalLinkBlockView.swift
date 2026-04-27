//
//  JournalLinkBlockView.swift
//  TravelLog
//
//  Created by 이상민 on 10/21/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import LinkPresentation

final class JournalLinkBlockView: BaseView, UITextFieldDelegate {
    struct PreviewData {
        let title: String?
        let description: String?
        let image: UIImage?
    }
    
    // MARK: - UI
    private let headerStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 6
        return view
    }()
    
    private let typeIcon: UIImageView = {
        let view = UIImageView()
        view.tintColor = .systemGreen
        view.image = UIImage(systemName: "link")
        return view
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.text = "링크"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        label.text = formatter.string(from: Date())
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gray
        return label
    }()
    
    private(set) var removeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .systemGray3
        return btn
    }()
    
    private let linkContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.tintColor = UIColor.darkGray.withAlphaComponent(0.6)
        view.image = UIImage(systemName: "globe")
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let inputStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
        return view
    }()

    private let validationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemRed
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    private let previewContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
        view.layer.cornerRadius = 12
        view.isHidden = true
        return view
    }()

    private let previewThumbnailImageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "globe")
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 10
        view.backgroundColor = .systemGray6
        return view
    }()

    private let previewTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = .label
        label.numberOfLines = 2
        return label
    }()

    private let previewDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .darkGray
        label.numberOfLines = 3
        return label
    }()

    private let previewStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGray
        label.numberOfLines = 1
        return label
    }()
    
    private(set) var urlTextField: UITextField = {
        let textField = UITextField()
        
        let placeholderText = "링크 URL을 입력하세요"
        
        let placeholderAttr = NSAttributedString(string: placeholderText, attributes: [
            .foregroundColor: UIColor.darkGray.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 14)
        ])
        textField.attributedPlaceholder = placeholderAttr
        
        textField.isUserInteractionEnabled = true
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 14)
        
        return textField
    }()
    
    private(set) var disposeBag = DisposeBag()
    private let metadataBag = DisposeBag()
    private(set) var previewData: PreviewData?
    private var validationTopConstraint: Constraint?
    private var validationHeightConstraint: Constraint?
    private var previewTopConstraint: Constraint?
    private var previewHeightConstraint: Constraint?
    
    // 닫기 버튼이 눌렸을 때 발생하는 ControlEvent
    var removeTapped: ControlEvent<Void> {
        return removeButton.rx.tap
    }
    
    // 현재 입력 필드의 텍스트 Observable
    var urlText: ControlProperty<String?> {
        return urlTextField.rx.text
    }

    var textContent: String? {
        return urlTextField.text
    }
    
    override func configureHierarchy() {
        addSubview(headerStack)
        addSubview(linkContainer)
        
        // Header Setup
        headerStack.addArrangedSubview(typeIcon)
        headerStack.addArrangedSubview(typeLabel)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(timeLabel)
        headerStack.addArrangedSubview(removeButton)

        // Link Container Setup
        linkContainer.addSubview(inputStackView)
        linkContainer.addSubview(validationLabel)
        linkContainer.addSubview(previewContainer)
        inputStackView.addArrangedSubview(iconImageView)
        inputStackView.addArrangedSubview(urlTextField)
        previewContainer.addSubview(previewThumbnailImageView)
        previewContainer.addSubview(previewTitleLabel)
        previewContainer.addSubview(previewDescriptionLabel)
        previewContainer.addSubview(previewStatusLabel)
        
        urlTextField.delegate = self
        bindPreview()
    }
    
    override func configureLayout() {
        headerStack.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.horizontalEdges.equalToSuperview().inset(16)
        }
        
        linkContainer.snp.makeConstraints { make in
            make.top.equalTo(headerStack.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(previewContainer.snp.bottom).offset(12)
        }

        inputStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
        }

        validationLabel.snp.makeConstraints { make in
            validationTopConstraint = make.top.equalTo(inputStackView.snp.bottom).offset(0).constraint
            make.leading.trailing.equalToSuperview().inset(12)
            validationHeightConstraint = make.height.equalTo(0).constraint
        }

        previewContainer.snp.makeConstraints { make in
            previewTopConstraint = make.top.equalTo(validationLabel.snp.bottom).offset(0).constraint
            make.leading.trailing.bottom.equalToSuperview().inset(12)
            previewHeightConstraint = make.height.equalTo(0).constraint
        }

        previewThumbnailImageView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(12)
            make.width.height.equalTo(64)
        }

        previewTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalTo(previewThumbnailImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(12)
        }

        previewDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(previewTitleLabel.snp.bottom).offset(6)
            make.leading.equalTo(previewTitleLabel)
            make.trailing.equalToSuperview().inset(12)
        }

        previewStatusLabel.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(previewDescriptionLabel.snp.bottom).offset(8)
            make.leading.equalTo(previewTitleLabel)
            make.trailing.bottom.equalToSuperview().inset(12)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
        
        self.snp.makeConstraints { make in
            make.bottom.equalTo(linkContainer.snp.bottom).offset(16)
        }
    }
    
    override func configureView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    func updateTimeLabel(with date: Date = Date()) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a hh:mm"
        timeLabel.text = formatter.string(from: date)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    private func bindPreview() {
        urlTextField.rx.text.orEmpty
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .distinctUntilChanged()
            .debounce(.milliseconds(500), scheduler: MainScheduler.instance)
            .flatMapLatest { [weak self] text -> Observable<PreviewState> in
                guard let self else { return .empty() }

                guard !text.isEmpty else {
                    return .just(.idle)
                }

                guard let normalized = URLNormalizer.normalized(text) else {
                    return .just(.invalid("올바른 링크 형식을 입력하세요"))
                }

                guard normalized.isValidDomain else {
                    return .just(.invalid("올바른 도메인 주소를 입력하세요"))
                }

                return self.fetchPreview(for: normalized.url)
                    .asObservable()
                    .startWith(.loading)
                    .catchAndReturn(.failed(normalized.url.absoluteString))
            }
            .observe(on: MainScheduler.instance)
            .bind(with: self) { owner, state in
                owner.applyPreview(state)
            }
            .disposed(by: metadataBag)
    }

    private func fetchPreview(for url: URL) -> Single<PreviewState> {
        Single.create { single in
            let provider = LPMetadataProvider()
            provider.startFetchingMetadata(for: url) { metadata, _ in
                guard let metadata else {
                    single(.success(.failed(url.absoluteString)))
                    return
                }

                let title = metadata.title ?? url.host ?? "링크 미리보기"
                let description = metadata.value(forKey: "summary") as? String ?? url.absoluteString

                if let imageProvider = metadata.imageProvider {
                    imageProvider.loadObject(ofClass: UIImage.self) { imageObj, _ in
                        let image = imageObj as? UIImage
                        let preview = PreviewData(title: title, description: description, image: image)
                        single(.success(.loaded(preview)))
                    }
                } else {
                    let preview = PreviewData(title: title, description: description, image: nil)
                    single(.success(.loaded(preview)))
                }
            }

            return Disposables.create()
        }
    }

    private func applyPreview(_ state: PreviewState) {
        switch state {
        case .idle:
            validationTopConstraint?.update(offset: 0)
            validationHeightConstraint?.update(offset: 0)
            validationLabel.isHidden = true
            validationLabel.text = nil
            previewTopConstraint?.update(offset: 0)
            previewHeightConstraint?.update(offset: 0)
            previewData = nil
            previewContainer.isHidden = true
            previewStatusLabel.text = nil
            previewTitleLabel.text = nil
            previewDescriptionLabel.text = nil
            previewThumbnailImageView.image = UIImage(systemName: "globe")
        case .invalid(let message):
            validationTopConstraint?.update(offset: 8)
            validationHeightConstraint?.update(offset: 18)
            validationLabel.isHidden = false
            validationLabel.text = message
            previewTopConstraint?.update(offset: 0)
            previewHeightConstraint?.update(offset: 0)
            previewData = nil
            previewContainer.isHidden = true
            previewTitleLabel.text = nil
            previewDescriptionLabel.text = nil
            previewStatusLabel.text = nil
            previewThumbnailImageView.image = UIImage(systemName: "globe")
        case .loading:
            validationTopConstraint?.update(offset: 0)
            validationHeightConstraint?.update(offset: 0)
            validationLabel.isHidden = true
            validationLabel.text = nil
            previewTopConstraint?.update(offset: 10)
            previewHeightConstraint?.update(offset: 112)
            previewData = nil
            previewContainer.isHidden = false
            previewTitleLabel.text = "미리보기를 불러오는 중"
            previewDescriptionLabel.text = "링크 제목과 설명을 확인하고 있습니다."
            previewStatusLabel.text = "잠시만 기다려주세요"
            previewThumbnailImageView.image = UIImage(systemName: "globe")
        case .loaded(let preview):
            validationTopConstraint?.update(offset: 0)
            validationHeightConstraint?.update(offset: 0)
            validationLabel.isHidden = true
            validationLabel.text = nil
            previewTopConstraint?.update(offset: 10)
            previewHeightConstraint?.update(offset: 112)
            previewData = preview
            previewContainer.isHidden = false
            previewTitleLabel.text = preview.title ?? "링크 미리보기"
            previewDescriptionLabel.text = preview.description ?? "설명이 없는 링크입니다."
            previewStatusLabel.text = "이 정보가 저장됩니다"
            previewThumbnailImageView.image = preview.image ?? UIImage(systemName: "globe")
        case .failed(let url):
            validationTopConstraint?.update(offset: 0)
            validationHeightConstraint?.update(offset: 0)
            validationLabel.isHidden = true
            validationLabel.text = nil
            previewTopConstraint?.update(offset: 10)
            previewHeightConstraint?.update(offset: 112)
            previewData = nil
            previewContainer.isHidden = false
            previewTitleLabel.text = "미리보기를 가져오지 못했어요"
            previewDescriptionLabel.text = url
            previewStatusLabel.text = "저장은 가능하지만 썸네일과 설명은 비어 있을 수 있어요"
            previewThumbnailImageView.image = UIImage(systemName: "globe")
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    private enum PreviewState {
        case idle
        case invalid(String)
        case loading
        case loaded(PreviewData)
        case failed(String)
    }
}
