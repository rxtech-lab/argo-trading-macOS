//
//  ChartTypes.swift
//  ArgoTradingSwift
//
//  Shared types for chart views (both legacy Swift Charts and LightweightCharts)
//

import Foundation

/// Represents the visible logical range of the chart (similar to lightweight-charts)
struct VisibleLogicalRange {
    let localFromIndex: Int
    let localToIndex: Int

    /// Distance from the beginning (negative if scrolled past start)
    var distanceFromStart: Int { localFromIndex }

    /// Whether near the start (within threshold)
    func isNearStart(threshold: Int = 10) -> Bool {
        localFromIndex < threshold
    }

    func isNearEnd(threshold: Int = 10, totalCount: Int) -> Bool {
        let distance = totalCount - localToIndex
        return distance < threshold
    }
}

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
