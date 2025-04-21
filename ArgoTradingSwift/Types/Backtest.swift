//
//  Backtest.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import Foundation

enum BacktestSelection: Identifiable, Hashable {
    case strategy
    case data(url: URL)
    case results

    var key: String {
        switch self {
        case .strategy:
            return "strategy"
        case .data(let url):
            return "data"
        case .results:
            return "results"
        }
    }

    var id: String { self.key }
}
