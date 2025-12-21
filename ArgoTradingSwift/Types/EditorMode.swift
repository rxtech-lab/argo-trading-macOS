//
//  EditorMode.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

enum EditorMode: String, CaseIterable, Identifiable {
    case Backtest
    case Trading

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .Backtest:
            return "chart.bar.xaxis"
        case .Trading:
            return "chart.line.uptrend.xyaxis"
        }
    }
}
