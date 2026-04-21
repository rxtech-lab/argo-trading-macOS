//
//  ResultTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/27/25.
//

import SwiftUI

enum ResultTab: String, CaseIterable, Identifiable {
    case general = "General"
    case trades = "Trades"
    case logs = "Logs"

    var id: String { self.rawValue }
}

enum GeneralSubView: String, CaseIterable, Identifiable {
    case info = "Info"
    case charts = "Charts"

    var id: String { self.rawValue }

    var systemImage: String {
        switch self {
        case .info: return "info.circle"
        case .charts: return "chart.bar.xaxis"
        }
    }
}

enum TradesSubView: String, CaseIterable, Identifiable {
    case trades = "Trades"
    case orders = "Orders"
    case marks = "Marks"

    var id: String { self.rawValue }

    var systemImage: String {
        switch self {
        case .trades: return "arrow.left.arrow.right"
        case .orders: return "list.bullet.rectangle"
        case .marks: return "mappin.and.ellipse"
        }
    }
}
