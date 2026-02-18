//
//  TradingSelection.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

enum TradingSelection: Identifiable, Hashable, Equatable {
    case run(url: URL)

    var key: String {
        switch self {
        case .run(let url):
            return "run-\(url.path)"
        }
    }

    var id: String { key }
}
