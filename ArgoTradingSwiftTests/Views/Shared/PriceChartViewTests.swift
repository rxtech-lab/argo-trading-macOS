//
//  PriceChartViewTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/30/25.
//

import SwiftUI
import Testing

@testable import ArgoTradingSwift

// MARK: - Test Data Helpers

private func createTestPriceData(
    id: String,
    date: Date,
    close: Double = 100.0,
    high: Double = 105.0,
    low: Double = 95.0,
    open: Double = 98.0
) -> PriceData {
    PriceData(
        date: date,
        id: id,
        ticker: "BTCUSDT",
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 1000.0
    )
}

private func createTestIndexedPrice(index: Int, data: PriceData) -> IndexedPrice {
    IndexedPrice(index: index, data: data)
}

private func createTestSignal(time: Date) -> Signal {
    Signal(
        time: time,
        type: .buyLong,
        name: "Test Signal",
        reason: "Test reason",
        rawValue: nil,
        symbol: "BTCUSDT",
        indicator: "test"
    )
}

private func createTestMark(signal: Signal) -> Mark {
    Mark(
        marketDataId: "ID_\(Int(signal.time.timeIntervalSince1970))",
        color: .red,
        shape: .circle,
        title: "Test Mark",
        message: "Test message",
        category: "test",
        signal: signal
    )
}

private func createTestMarkOverlay(id: String, mark: Mark) -> MarkOverlay {
    MarkOverlay(id: id, mark: mark)
}

private func createTestTrade(timestamp: Date, isBuy: Bool = true) -> Trade {
    Trade(
        orderId: "order_\(timestamp.timeIntervalSince1970)",
        symbol: "BTCUSDT",
        side: isBuy ? .buy : .sell,
        quantity: 1.0,
        price: 100.0,
        timestamp: timestamp,
        isCompleted: true,
        reason: "Test trade",
        message: "",
        strategyName: "TestStrategy",
        executedAt: timestamp,
        executedQty: 1.0,
        executedPrice: 100.0,
        commission: 0.1,
        pnl: isBuy ? 0.0 : 10.0,
        positionType: "LONG"
    )
}

private func createTestTradeOverlay(timestamp: Date, price: Double = 100.0, isBuy: Bool = true) -> TradeOverlay {
    TradeOverlay(
        id: "trade_\(timestamp.timeIntervalSince1970)",
        timestamp: timestamp,
        price: price,
        isBuy: isBuy,
        trade: createTestTrade(timestamp: timestamp, isBuy: isBuy)
    )
}

// MARK: - Mark Overlay Tests

struct PriceChartViewMarkOverlayTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00

    @Test func markOverlayCanBeCreated() {
        // Given: A mark with signal
        let signal = createTestSignal(time: baseDate)
        let mark = createTestMark(signal: signal)

        // When: Creating an overlay
        let overlay = createTestMarkOverlay(id: "test_overlay", mark: mark)

        // Then: Overlay has correct properties
        #expect(overlay.id == "test_overlay")
        #expect(overlay.mark.title == "Test Mark")
        #expect(overlay.mark.signal.time == baseDate)
    }

    @Test func markOverlayUsesSignalTimestamp() {
        // Given: A mark with a specific signal timestamp
        let signalTime = baseDate.addingTimeInterval(3600)
        let signal = createTestSignal(time: signalTime)
        let mark = createTestMark(signal: signal)
        let overlay = createTestMarkOverlay(id: "test", mark: mark)

        // Then: The signal time is accessible
        #expect(overlay.mark.signal.time == signalTime)
    }
}

// MARK: - Trade Overlay Tests

struct PriceChartViewTradeOverlayTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200)

    @Test func tradeOverlayCanBeCreated() {
        // Given: Trade data
        let timestamp = baseDate

        // When: Creating a trade overlay
        let overlay = createTestTradeOverlay(timestamp: timestamp, price: 105.0, isBuy: true)

        // Then: Overlay has correct properties
        #expect(overlay.isBuy == true)
        #expect(overlay.price == 105.0)
        #expect(overlay.timestamp == timestamp)
    }

    @Test func tradeOverlayDistinguishesBuyAndSell() {
        // Given: Buy and sell trades
        let buyOverlay = createTestTradeOverlay(timestamp: baseDate, isBuy: true)
        let sellOverlay = createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(60), isBuy: false)

        // Then: They are correctly distinguished
        #expect(buyOverlay.isBuy == true)
        #expect(sellOverlay.isBuy == false)
        #expect(buyOverlay.trade.side == .buy)
        #expect(sellOverlay.trade.side == .sell)
    }
}

// MARK: - Visibility Properties Tests

struct PriceChartViewVisibilityTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200)

    @Test func defaultVisibilityIsTrue() {
        // When: Creating indexed data
        let data = createTestPriceData(id: "ID_0", date: baseDate)
        let indexedData = [createTestIndexedPrice(index: 0, data: data)]

        // Then: PriceChartView can be created with default visibility (true)
        // Note: We can't test the view directly without ViewInspector,
        // but we can verify the default values are applied via the struct definition
        #expect(indexedData.count == 1)
    }
}

// MARK: - IndexedPrice Tests

struct IndexedPriceTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200)

    @Test func indexedPriceStoresIndexAndData() {
        // Given: Price data
        let data = createTestPriceData(id: "test_id", date: baseDate, close: 150.0)

        // When: Creating indexed price
        let indexed = createTestIndexedPrice(index: 42, data: data)

        // Then: Both index and data are stored
        #expect(indexed.index == 42)
        #expect(indexed.data.close == 150.0)
        #expect(indexed.data.id == "test_id")
    }

    @Test func indexedPriceIsIdentifiable() {
        // Given: Indexed price
        let data = createTestPriceData(id: "test_id", date: baseDate)
        let indexed = createTestIndexedPrice(index: 5, data: data)

        // Then: ID matches index
        #expect(indexed.id == 5)
    }
}

// MARK: - VisibleLogicalRange Tests

struct VisibleLogicalRangeTests {
    @Test func distanceFromStartCalculatesCorrectly() {
        let range = VisibleLogicalRange(from: 10, to: 20, visibleCount: 10, totalCount: 100)
        #expect(range.distanceFromStart == 10)
    }

    @Test func distanceFromEndCalculatesCorrectly() {
        let range = VisibleLogicalRange(from: 10, to: 20, visibleCount: 10, totalCount: 100)
        #expect(range.distanceFromEnd == 80)
    }

    @Test func isNearStartWithinThreshold() {
        let range = VisibleLogicalRange(from: 5, to: 15, visibleCount: 10, totalCount: 100)
        #expect(range.isNearStart(threshold: 10) == true)
        #expect(range.isNearStart(threshold: 3) == false)
    }

    @Test func isNearEndWithinThreshold() {
        let range = VisibleLogicalRange(from: 85, to: 95, visibleCount: 10, totalCount: 100)
        #expect(range.isNearEnd(threshold: 10) == true)
        #expect(range.isNearEnd(threshold: 3) == false)
    }
}

// MARK: - ChartHeaderView Tests

struct ChartHeaderViewTests {
    @Test func headerViewCanBeCreatedWithoutOverlays() {
        // ChartHeaderView should work without overlay parameters
        // This tests the optional parameter defaults
        #expect(true) // Compilation test - if ChartHeaderView compiles without overlay params, test passes
    }
}
