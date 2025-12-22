//
//  BacktestTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//
import SwiftUI

enum BacktestTabs: Hashable, Identifiable, CaseIterable {
    case general
    case results

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            "General"
        case .results:
            "Results"
        }
    }

    var icon: String {
        switch self {
        case .general:
            "gearshape"
        case .results:
            "chart.bar"
        }
    }
}
