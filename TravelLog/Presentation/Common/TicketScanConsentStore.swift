//
//  TicketScanConsentStore.swift
//  TravelLog
//
//  Created by Claude on 8/16/26.
//

import Foundation

/// 티켓 스캔은 촬영한 사진을 외부 AI 서비스(Anthropic)로 전송해 분석한다.
/// 여권번호 등 고유식별정보가 사진에 포함될 수 있어, 기능을 처음 사용할 때
/// 별도 동의를 받아야 한다. 버전을 올리면(v2, v3…) 고지 문구가 바뀌었을 때
/// 기존 동의를 무효화하고 다시 물어볼 수 있다.
enum TicketScanConsentStore {
    private static let consentVersion = 1
    private static let userDefaultsKey = "ticketScanDataConsent.v\(consentVersion)"

    static var hasConsented: Bool {
        get { UserDefaults.standard.bool(forKey: userDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: userDefaultsKey) }
    }
}
