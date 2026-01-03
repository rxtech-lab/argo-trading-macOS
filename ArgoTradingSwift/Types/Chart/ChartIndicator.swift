//
//  ChartIndicator.swift
//  ArgoTradingSwift
//
//  Technical indicators for chart overlays
//

import Foundation

/// Technical indicators that can be displayed on the chart
enum ChartIndicator: String, CaseIterable, Identifiable, Codable {
    case sma20 = "SMA 20"
    case sma50 = "SMA 50"
    case sma200 = "SMA 200"
    case ema12 = "EMA 12"
    case ema26 = "EMA 26"
    case bollingerBands = "Bollinger Bands"
    case rsi = "RSI"
    case macd = "MACD"
    case volume = "Volume"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// JavaScript function name to add this indicator
    var jsAddFunction: String {
        switch self {
        case .sma20: return "addSMA(20)"
        case .sma50: return "addSMA(50)"
        case .sma200: return "addSMA(200)"
        case .ema12: return "addEMA(12)"
        case .ema26: return "addEMA(26)"
        case .bollingerBands: return "addBollingerBands(20, 2)"
        case .rsi: return "addRSI(14)"
        case .macd: return "addMACD(12, 26, 9)"
        case .volume: return "showVolume(true)"
        }
    }

    /// JavaScript function name to remove this indicator
    var jsRemoveFunction: String {
        switch self {
        case .sma20: return "removeSMA(20)"
        case .sma50: return "removeSMA(50)"
        case .sma200: return "removeSMA(200)"
        case .ema12: return "removeEMA(12)"
        case .ema26: return "removeEMA(26)"
        case .bollingerBands: return "removeBollingerBands()"
        case .rsi: return "removeRSI()"
        case .macd: return "removeMACD()"
        case .volume: return "showVolume(false)"
        }
    }

    /// Indicator color for display
    var color: String {
        switch self {
        case .sma20: return "#FF6B6B"
        case .sma50: return "#4ECDC4"
        case .sma200: return "#45B7D1"
        case .ema12: return "#96CEB4"
        case .ema26: return "#FFEAA7"
        case .bollingerBands: return "#DDA0DD"
        case .rsi: return "#FF9F43"
        case .macd: return "#6C5CE7"
        case .volume: return "#74B9FF"
        }
    }

    /// Whether this indicator is displayed in a separate pane (below main chart)
    var isSeparatePane: Bool {
        switch self {
        case .rsi, .macd:
            return true
        default:
            return false
        }
    }

    /// System image name for the indicator
    var systemImage: String {
        switch self {
        case .sma20, .sma50, .sma200, .ema12, .ema26:
            return "line.diagonal"
        case .bollingerBands:
            return "arrow.up.and.down"
        case .rsi:
            return "waveform.path.ecg"
        case .macd:
            return "chart.bar.xaxis"
        case .volume:
            return "chart.bar"
        }
    }
}
