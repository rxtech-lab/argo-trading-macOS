//
//  TradingSelection.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

enum TradingSelection: Identifiable, Hashable, Equatable {
    case session(id: UUID)

    var key: String {
        switch self {
        case .session(let id):
            return "session-\(id.uuidString)"
        }
    }

    var id: String { key }
}
