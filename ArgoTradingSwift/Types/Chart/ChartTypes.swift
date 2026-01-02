//
//  ChartTypes.swift
//  ArgoTradingSwift
//
//  Shared types for chart views (both legacy Swift Charts and LightweightCharts)
//

import Foundation

/// Represents the visible logical range of the chart (similar to lightweight-charts)
struct VisibleLogicalRange {
    let globalFromIndex: Int
    let localFromIndex: Int
    let globalToIndex: Int
    let localToIndex: Int
    let totalCount: Int

    /// Distance from the beginning (negative if scrolled past start)
    var distanceFromStart: Int { localFromIndex }

    /// Distance from the end
    var distanceFromEnd: Int { totalCount - localToIndex }

    /// Whether near the start (within threshold)
    func isNearStart(threshold: Int = 10) -> Bool {
        localToIndex < threshold
    }

    /// Whether near the end (within threshold)
    func isNearEnd(threshold: Int = 10) -> Bool {
        distanceFromEnd < threshold
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
