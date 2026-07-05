//
//  LinkPreviewVisualTestViewController.swift
//  TravelLog
//
//  Created by 이상민 on 7/6/26.
//

import UIKit
import SnapKit

#if DEBUG
final class LinkPreviewVisualTestViewController: BaseViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override func configureHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
    }

    override func configureLayout() {
        scrollView.snp.makeConstraints {
            $0.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentStack.snp.makeConstraints {
            $0.edges.equalTo(scrollView.contentLayoutGuide).inset(16)
            $0.width.equalTo(scrollView.frameLayoutGuide).offset(-32)
        }
    }

    override func configureView() {
        title = "링크 미리보기 UI 테스트"
        view.backgroundColor = .systemGroupedBackground

        contentStack.axis = .vertical
        contentStack.spacing = 12

        let headerLabel = UILabel()
        headerLabel.text = "30개 URL을 실제 링크 미리보기 카드로 렌더링"
        headerLabel.font = .boldSystemFont(ofSize: 18)
        headerLabel.textColor = .label
        headerLabel.numberOfLines = 0
        contentStack.addArrangedSubview(headerLabel)

        for (index, url) in Self.urls.enumerated() {
            let blockView = JournalLinkBlockView()
            blockView.accessibilityIdentifier = "linkPreviewVisualCard_\(index)"
            blockView.updateTimeLabel()
            contentStack.addArrangedSubview(blockView)

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.4) {
                blockView.urlTextField.text = url
                blockView.urlTextField.sendActions(for: .editingChanged)
            }
        }
    }
}

private extension LinkPreviewVisualTestViewController {
    static let urls = [
        "naver.com",
        "www.naver.com",
        "google.com",
        "youtube.com",
        "apple.com",
        "github.com",
        "stackoverflow.com",
        "openai.com",
        "notion.so",
        "figma.com",
        "reddit.com",
        "samsung.com",
        "kakao.com",
        "daum.net",
        "coupang.com",
        "musinsa.com",
        "yanolja.com",
        "seoul.go.kr",
        "visitseoul.net",
        "botanicpark.seoul.go.kr/front/main.do",
        "korea.kr",
        "kto.visitkorea.or.kr",
        "letskorail.com",
        "socar.kr",
        "tmap.co.kr",
        "map.naver.com",
        "developer.apple.com",
        "developer.android.com",
        "firebase.google.com",
        "airbnb.com"
    ]
}
#endif
