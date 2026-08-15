//
//  TicketScanErrorPresenter.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation

//MARK: - TicketScanError를 사용자에게 보여줄 한국어 안내 문구로 변환
enum TicketScanErrorPresenter {

    static func message(for error: TicketScanError) -> String {
        switch error {
        case .offline:
            return "인터넷 연결을 확인한 뒤 다시 시도해주세요."
        case .invalidImage:
            return "이미지를 처리할 수 없어요. 다른 사진으로 다시 시도해주세요."
        case .refused:
            return "이 이미지는 분석할 수 없어요. 다른 사진으로 시도해주세요."
        case .serverBusy:
            return "서버가 혼잡해요. 잠시 후 다시 시도해주세요."
        case .unknown:
            return "티켓 이미지를 분석하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
