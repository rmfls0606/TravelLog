//
//  CityPhotoProxyAppCheckModifier.swift
//  TravelLog
//
//  Created by Claude on 8/17/26.
//
//  Kingfisher는 Firebase SDK가 아니라 일반 URLSession으로 이미지를 요청하기 때문에,
//  Firestore/Functions 호출과 달리 App Check 토큰이 자동으로 실리지 않는다. cityPhotoProxy
//  (Cloud Functions)로 가는 요청에만 이 토큰을 헤더로 직접 붙여준다 — 다른 호스트(예:
//  Firebase Storage에 이미 저장된 이미지 URL)로 가는 요청은 그대로 둔다.

import Foundation
import Kingfisher
import FirebaseAppCheck

struct CityPhotoProxyAppCheckModifier: AsyncImageDownloadRequestModifier {
    var onDownloadTaskStarted: ((DownloadTask?) -> Void)?

    func modified(for request: URLRequest) async -> URLRequest? {
        guard let host = request.url?.host, host.hasSuffix("cloudfunctions.net") else {
            return request
        }

        var modifiedRequest = request
        if let token = try? await AppCheck.appCheck().token(forcingRefresh: false) {
            modifiedRequest.setValue(token.token, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        return modifiedRequest
    }
}
