//
//  ChartType.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation

enum ChartType: String, CaseIterable, Identifiable {
    case line = "Line"
    case candlestick = "Candlestick"

    var id: String { rawValue }
}
