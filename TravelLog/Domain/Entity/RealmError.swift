//
//  RealmError.swift
//  TravelLog
//
//  Created by 이상민 on 10/15/25.
//

import Foundation

enum RealmError: LocalizedError{
    case saveFailure
    case fetchFailure
    case deleteFailure
    case instanceNotFound
    
    var errorDescription: String?{
        switch self {
        case .saveFailure:
            return "저장이 완료되지 않았습니다.\n잠시 후 다시 시도해주세요."
        case .fetchFailure:
            return "데이터를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요."
        case .deleteFailure:
            return "데이터를 삭제하는데 실패했습니다.\n잠시 후 다시 시도해주세요."
        case .instanceNotFound:
            return "데이터 처리 중 문제가 발생했습니다.\n잠시 후 다시 시도해주세요."
        }
    }
}
