//
//  TicketScanError.swift
//  TravelLog
//
//  Created by Claude on 8/10/26.
//

import Foundation

// 티켓 스캔 파이프라인에서 발생할 수 있는 실패를, Firebase/네트워크 구현 세부사항과 분리해
// 상위 레이어(Domain/Presentation)가 이해할 수 있는 형태로 표현
enum TicketScanError: Error, Equatable {
    // 인터넷 연결이 없거나 불안정함
    case offline
    // 서버가 이미지를 처리할 수 없다고 판단함 (형식/크기 문제 등)
    case invalidImage
    // 모델이 이미지 분석을 거부함
    case refused
    // 서버가 일시적으로 과부하 상태이거나 응답이 지연됨
    case serverBusy
    // 위 경우에 해당하지 않는 그 외 실패
    case unknown
}
