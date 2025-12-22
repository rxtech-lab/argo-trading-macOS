//
//  Backtest.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import Foundation

enum BacktestSelection: Identifiable, Hashable {
    case strategy(url: URL)
    case data(url: URL)
    case results

    var key: String {
        switch self {
        case .strategy(let url):
            return "strategy-\(url.lastPathComponent)"
        case .data(let url):
            return "data-\(url.lastPathComponent)"
        case .results:
            return "results"
        }
    }

    var id: String { self.key }
}
