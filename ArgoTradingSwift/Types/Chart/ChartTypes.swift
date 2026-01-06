//
//  ChartTypes.swift
//  ArgoTradingSwift
//
//  Shared types for chart views (both legacy Swift Charts and LightweightCharts)
//

import Foundation
import LightweightChart

/// Trade overlay data for chart visualization
struct TradeOverlay: Identifiable {
    let id: String
    let timestamp: Date
    let price: Double
    let isBuy: Bool
    let trade: Trade
}

/// Mark overlay data for chart visualization
struct MarkOverlay: Identifiable {
    let id: String
    let mark: Mark
    let alignedTime: Date // Timestamp aligned to chart interval for TradingView rendering
}

/// Internal scroll change event for debouncing
struct ScrollChangeEvent: Equatable {
    let currentScrollIndex: Int
    let totalCount: Int
    let firstGlobalIndex: Int

    var localIndex: Int {
        currentScrollIndex - firstGlobalIndex
    }
}

// MARK: - MarkerDataJS Conversion Extensions

extension TradeOverlay {
    /// Convert TradeOverlay to MarkerDataJS for LightweightChart
    func toMarkerDataJS() -> MarkerDataJS {
        var marker = MarkerDataJS(
            time: timestamp.timeIntervalSince1970,
            position: "aboveBar",  // Trades always on top
            color: isBuy ? "#26a69a" : "#ef5350",
            shape: isBuy ? "arrowUp" : "arrowDown",
            text: isBuy ? "BUY" : "SELL",
            id: id,
            markerType: "trade"
        )
        marker.isBuy = isBuy
        marker.symbol = trade.symbol
        marker.positionType = trade.positionType
        marker.executedQty = trade.executedQty
        marker.executedPrice = trade.executedPrice
        marker.pnl = trade.pnl
        marker.reason = trade.reason
        return marker
    }
}

extension MarkOverlay {
    /// Convert MarkOverlay to MarkerDataJS for LightweightChart
    func toMarkerDataJS() -> MarkerDataJS {
        var marker = MarkerDataJS(
            time: alignedTime.timeIntervalSince1970,
            position: "belowBar",  // Marks always on bottom
            color: mark.color.toHexString(),
            shape: mark.shape.toJSShape(),
            text: mark.title,
            id: id,
            markerType: "mark"
        )
        marker.title = mark.title
        marker.category = mark.category
        marker.message = mark.message
        marker.signalType = mark.signal.type.rawValue
        marker.signalReason = mark.signal.reason
        return marker
    }
}
