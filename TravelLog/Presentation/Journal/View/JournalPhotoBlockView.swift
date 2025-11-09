//
//  JournalPhotoBlockView.swift
//  TravelLog
//
//  Created by 이상민 on 10/30/25.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

final class JournalPhotoBlockView: BaseView, UITextViewDelegate {
    
    // MARK: - UI
    private let headerStack = UIStackView()
    private let typeIcon = UIImageView(image: UIImage(systemName: "camera"))
    private let typeLabel = UILabel()
    private let timeLabel = UILabel()
    private let removeButton = UIButton(type: .system)
    
    private let photoContainer = UIStackView()
    
    private let dashBox: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    private let cameraSelectButton: UIButton = {
        let btn = UIButton()
        var config = UIButton.Configuration.filled()
        config.baseForegroundColor = .darkGray
        config.baseBackgroundColor = .systemGray6.withAlphaComponent(0.2)
        var imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        config.image = UIImage(systemName: "camera")
        config.preferredSymbolConfigurationForImage = imageConfig
        config.imagePlacement = .top
        config.imagePadding = 8
        config.titlePadding = 8
        config.attributedTitle = AttributedString("사진으로 담기", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 15)
        ]))
        btn.configuration = config
        return btn
    }()
    
    private let photoScrollView: UIScrollView = {
        let view = UIScrollView()
        view.showsHorizontalScrollIndicator = false
        view.isHidden = true
        return view
    }()
    
    private let photoStackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = 8
        return view
    }()
    
    private let textContainer = UIView()
    let textView = UITextView()
    private let placeholderLabel = UILabel()
    
    // MARK: - Rx
    let disposeBag = DisposeBag()
    let textChanged = PublishRelay<String>()
    let removeTapped = PublishRelay<Void>()
    let cameraTapped = PublishRelay<Void>()
    
    private(set) var selectedImages: [UIImage] = [] //현재 보여줄 이미지들
    
    private var lastSentText: String = ""  // 중복 방지용 캐시
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        dashBox.layoutIfNeeded()
        dashBox.layer.sublayers?.removeAll(where: { $0.name == "dashedBorder" })
        
        let layer = CAShapeLayer()
        layer.name = "dashedBorder"
        let strokeColor = UIColor(red: 120/255, green: 130/255, blue: 255/255, alpha: 0.7)
        layer.strokeColor = strokeColor.cgColor
        layer.fillColor = nil
        layer.lineDashPattern = [5, 3]
        layer.lineWidth = 1.2
        layer.path = UIBezierPath(roundedRect: dashBox.bounds, cornerRadius: 12).cgPath
        dashBox.layer.addSublayer(layer)
    }
    
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
        addSubview(photoContainer)
        addSubview(textContainer)
        
        photoContainer.axis = .vertical
        photoContainer.spacing = 12
        photoContainer.addArrangedSubview(dashBox)
        photoContainer.addArrangedSubview(photoScrollView)
        
        dashBox.addSubview(cameraSelectButton)
        photoScrollView.addSubview(photoStackView)
        
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
        
        photoScrollView.showsHorizontalScrollIndicator = false
        photoStackView.axis = .horizontal
        photoStackView.spacing = 8
        
        textView.delegate = self
    }
    
    private func setupLayout() {
        headerStack.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        
        photoContainer.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        
        dashBox.snp.makeConstraints { $0.height.equalTo(120) }
        cameraSelectButton.snp.makeConstraints { $0.edges.equalToSuperview() }
        
        photoScrollView.snp.makeConstraints { $0.height.equalTo(120) }
        photoStackView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }
        
        textContainer.snp.makeConstraints {
            $0.top.equalTo(photoContainer.snp.bottom).offset(10)
            $0.leading.trailing.bottom.equalToSuperview().inset(16)
            $0.height.greaterThanOrEqualTo(80)
        }
        textView.snp.makeConstraints { $0.edges.equalToSuperview().inset(12) }
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
        typeIcon.tintColor = .systemPink
        typeLabel.text = "사진"
        typeLabel.font = .systemFont(ofSize: 14, weight: .medium)
        typeLabel.textColor = .systemPink
        
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
        
        placeholderLabel.text = "사진에 대한 설명을 적어보세요"
        placeholderLabel.font = .systemFont(ofSize: 15)
        placeholderLabel.textColor = .systemGray3
        
        // Rx 바인딩
        textView.rx.text.orEmpty
            .map { text -> String in
                // 엔터·공백만 입력한 경우는 빈 문자열로 처리
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return ""
                }
                return text
            }
            .distinctUntilChanged()
            .bind(with: self) { owner, text in
                // placeholder 표시/숨김
                owner.placeholderLabel.isHidden = !text.isEmpty
                
                // 텍스트 변경 이벤트 전달
                owner.textChanged.accept(text)
            }
            .disposed(by: disposeBag)
        
        cameraSelectButton.rx.tap
            .bind(to: cameraTapped)
            .disposed(by: disposeBag)
        
        
        removeButton.rx.tap
            .bind(to: removeTapped)
            .disposed(by: disposeBag)
    }
    
    func updateSelectedPhotos(_ images: [UIImage]) {
        self.selectedImages = images
        if images.isEmpty{
            showPlaceholder(true)
        }else{
            showPlaceholder(false)
            reloadPhotoStack()
        }
    }
    
    private func showPlaceholder(_ show: Bool){
        dashBox.isHidden = !show
        photoScrollView.isHidden = show
    }
    
    private func reloadPhotoStack(){
        // 기존 썸네일 제거
        photoStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // 1) 항상 첫 번째는 +버튼
        let addButton = makeAddThumbButton()
        photoStackView.addArrangedSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.width.height.equalTo(120)
        }
        
        // 2) 그 다음부터는 썸네일
        for image in selectedImages {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 10
            imageView.snp.makeConstraints { make in
                make.width.height.equalTo(120)
            }
            photoStackView.addArrangedSubview(imageView)
        }
    }
    
    private func makeAddThumbButton() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.systemGray6
        config.baseForegroundColor = .label
        let imageConfig = UIImage.SymbolConfiguration(scale: .small)
        config.preferredSymbolConfigurationForImage = imageConfig
        config.image = UIImage(systemName: "camera")
        config.imagePlacement = .top
        config.imagePadding = 4
        config.titlePadding = 4
        config.attributedTitle = AttributedString("사진으로 담기", attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.label
        ]))
        
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor.systemGray4.cgColor
        btn.addAction(UIAction(handler: { [weak self] _ in
            self?.cameraTapped.accept(())
        }), for: .touchUpInside)
        btn.configuration = config
        return btn
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Return 키 누를 시 키보드 내리기
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    // MARK: - Public Accessors
    var textContent: String {
        return textView.text ?? ""
    }
}
