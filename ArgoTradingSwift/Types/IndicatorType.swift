//
//  IndicatorType.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/3/26.
//

import Foundation

/// Types of technical indicators supported by the chart
enum IndicatorType: String, CaseIterable, Identifiable, Codable {
    case sma = "SMA"
    case ema = "EMA"
    case vwap = "VWAP"
    case rsi = "RSI"
    case macd = "MACD"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// Whether this indicator overlays on the price chart or needs a separate pane
    var isOverlay: Bool {
        switch self {
        case .sma, .ema, .vwap:
            return true
        case .rsi, .macd:
            return false
        }
    }

    /// Default parameters for this indicator type
    var defaultParameters: [String: Int] {
        switch self {
        case .sma:
            return ["period": 20]
        case .ema:
            return ["period": 12]
        case .vwap:
            return [:]
        case .rsi:
            return ["period": 14]
        case .macd:
            return ["fastPeriod": 12, "slowPeriod": 26, "signalPeriod": 9]
        }
    }

    /// System image for the indicator
    var systemImage: String {
        switch self {
        case .sma, .ema:
            return "chart.line.uptrend.xyaxis"
        case .vwap:
            return "chart.bar.fill"
        case .rsi:
            return "gauge.with.needle"
        case .macd:
            return "waveform.path.ecg"
        }
    }

    /// Default color for the indicator line (hex string)
    var defaultColor: String {
        switch self {
        case .sma:
            return "#FF9800"
        case .ema:
            return "#2196F3"
        case .vwap:
            return "#9C27B0"
        case .rsi:
            return "#4CAF50"
        case .macd:
            return "#E91E63"
        }
    }
}
