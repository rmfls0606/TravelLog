//
//  LinkPreviewMemoryCacheTests.swift
//  TravelLogTests
//
//  Created by 이상민 on 7/5/26.
//

import XCTest
@testable import TravelLog

final class LinkPreviewMemoryCacheTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LinkPreviewMemoryCache.shared.removeAll()
    }

    override func tearDown() {
        LinkPreviewMemoryCache.shared.removeAll()
        super.tearDown()
    }

    //MARK: - 제목과 설명이 있는 정상 링크 미리보기는 메모리 캐시에 저장되고 다시 조회되는지 확인
    func testStoresAndReturnsUsablePreview() throws {
        // XCTUnwrap: URL 생성이 실패하면 테스트를 즉시 실패
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let preview = CachedLinkPreview(title: "Example", description: "Description", image: nil)

        // store로 캐시에 저장하고, preview(for:)로 같은 URL의 캐시 값을 조회
        LinkPreviewMemoryCache.shared.store(preview, for: url)
        let cachedPreview = LinkPreviewMemoryCache.shared.preview(for: url)

        XCTAssertEqual(cachedPreview?.title, "Example")
        XCTAssertEqual(cachedPreview?.description, "Description")
    }

    //MARK: - 네트워크 실패처럼 제목과 설명이 모두 없는 결과는 캐시에 남기지 않는지 확인
    func testDoesNotStorePreviewWithoutUsableMetadata() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let preview = CachedLinkPreview(title: nil, description: nil, image: nil)

        LinkPreviewMemoryCache.shared.store(preview, for: url)

        // 실패성 결과가 캐시되면 네트워크 복구 후에도 빈 미리보기가 재사용될 수 있으므로 nil이어야 함
        XCTAssertNil(LinkPreviewMemoryCache.shared.preview(for: url))
    }

    //MARK: - 설명이 공백뿐인 결과도 사용 가능한 메타데이터로 보지 않고 캐시하지 않는지 확인
    func testDoesNotStorePreviewWithEmptyDescription() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let preview = CachedLinkPreview(title: "Example", description: "   ", image: nil)

        LinkPreviewMemoryCache.shared.store(preview, for: url)

        XCTAssertNil(LinkPreviewMemoryCache.shared.preview(for: url))
    }

    //MARK: - www 유무만 다른 입력은 같은 사이트로 보고 동일한 메모리 캐시 키를 사용하는지 확인
    func testUsesSameCacheKeyForWWWHost() throws {
        let wwwURL = try XCTUnwrap(URL(string: "https://www.naver.com"))
        let plainURL = try XCTUnwrap(URL(string: "https://naver.com"))
        let preview = CachedLinkPreview(title: "Naver", description: "Search", image: nil)

        LinkPreviewMemoryCache.shared.store(preview, for: wwwURL)
        let cachedPreview = LinkPreviewMemoryCache.shared.preview(for: plainURL)

        XCTAssertEqual(cachedPreview?.title, "Naver")
        XCTAssertEqual(cachedPreview?.description, "Search")
    }

    //MARK: - 캐시 개수 제한을 초과하면 가장 오래된 항목부터 제거되는지 확인
    func testEvictsOldestPreviewWhenCountLimitIsExceeded() throws {
        let firstURL = try XCTUnwrap(URL(string: "https://example0.com"))

        // coubtLimit이 50이므로 51개를 저장해 첫 번쨰 항목이 밀려나는 시나리오 만듦
        for index in 0...50 {
            let url = try XCTUnwrap(URL(string: "https://example\(index).com"))
            let preview = CachedLinkPreview(
                title: "Example \(index)",
                description: "Description \(index)",
                image: nil
            )
            LinkPreviewMemoryCache.shared.store(preview, for: url)
        }

        let lastURL = try XCTUnwrap(URL(string: "https://example50.com"))

        // 첫 번째 URL은 제거되고, 가장 최근에 넣은 URL은 남아 있어야 함
        XCTAssertNil(LinkPreviewMemoryCache.shared.preview(for: firstURL))
        XCTAssertEqual(LinkPreviewMemoryCache.shared.preview(for: lastURL)?.title, "Example 50")
    }
}
