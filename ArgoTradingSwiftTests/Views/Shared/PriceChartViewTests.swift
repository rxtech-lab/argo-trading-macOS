//
//  PriceChartViewTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/30/25.
//

import SwiftUI
import Testing
import ViewInspector

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

private func createTestMark(marketDataId: String) -> Mark {
    Mark(
        marketDataId: marketDataId,
        color: "#FF0000",
        shape: .circle,
        title: "Test Mark",
        message: "Test message",
        category: "test",
        signal: nil
    )
}

private func createTestMarkOverlay(marketDataId: String, price: Double = 100.0) -> MarkOverlay {
    MarkOverlay(
        id: "overlay_\(marketDataId)",
        marketDataId: marketDataId,
        price: price,
        mark: createTestMark(marketDataId: marketDataId)
    )
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

// MARK: - Mark Overlay Filter Tests

struct PriceChartViewMarkOverlayFilterTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00

    @Test func overlaysWithMatchingMarketDataIdAreVisible() {
        // Given: Price data with IDs "ID_0", "ID_1", "ID_2"
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Mark overlays with matching IDs
        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_0"),
            createTestMarkOverlay(marketDataId: "ID_2"),
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Both overlays should be visible
        #expect(visible.count == 2)
        #expect(visible[0].overlay.marketDataId == "ID_0")
        #expect(visible[1].overlay.marketDataId == "ID_2")
    }

    @Test func overlaysWithNonMatchingMarketDataIdAreFiltered() {
        // Given: Price data with IDs "ID_0", "ID_1", "ID_2"
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Mark overlays with non-matching IDs
        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_99"),
            createTestMarkOverlay(marketDataId: "ID_100"),
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: No overlays should be visible
        #expect(visible.isEmpty)
    }

    @Test func overlaysWithEmptyIndexedDataReturnsEmpty() {
        // Given: Empty indexed data
        let indexedData: [IndexedPrice] = []

        // And: Mark overlays
        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_0")
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: No overlays should be visible
        #expect(visible.isEmpty)
    }

    @Test func overlaysPriceUsesHighForCandlestick() {
        // Given: Price data with specific high value
        let indexedData = [
            createTestIndexedPrice(
                index: 0,
                data: createTestPriceData(id: "ID_0", date: baseDate, close: 100.0, high: 110.0)
            )
        ]

        // And: Mark overlay
        let markOverlays = [createTestMarkOverlay(marketDataId: "ID_0")]

        // When: Filtering with candlestick chart type
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Price should be the high value
        #expect(visible.count == 1)
        #expect(visible[0].price == 110.0)
    }

    @Test func overlaysPriceUsesCloseForLine() {
        // Given: Price data with specific close value
        let indexedData = [
            createTestIndexedPrice(
                index: 0,
                data: createTestPriceData(id: "ID_0", date: baseDate, close: 100.0, high: 110.0)
            )
        ]

        // And: Mark overlay
        let markOverlays = [createTestMarkOverlay(marketDataId: "ID_0")]

        // When: Filtering with line chart type
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .line
        )

        // Then: Price should be the close value
        #expect(visible.count == 1)
        #expect(visible[0].price == 100.0)
    }

    @Test func markOverlayBecomesVisibleWhenDataLoaded() {
        // Scenario 3: Overlay not in range initially, then becomes visible

        // Given: Mark overlay with ID "ID_100"
        let markOverlays = [createTestMarkOverlay(marketDataId: "ID_100")]

        // And: Initially, indexed data does NOT contain "ID_100"
        let initialData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // When: Filtering with initial data
        let initialVisible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: initialData,
            chartType: .candlestick
        )

        // Then: Overlay should NOT be visible
        #expect(initialVisible.isEmpty)

        // And: Later, indexed data IS loaded with "ID_100"
        let updatedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index + 99)", // ID_99, ID_100, ID_101
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // When: Filtering with updated data
        let updatedVisible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: updatedData,
            chartType: .candlestick
        )

        // Then: Overlay should now be visible
        #expect(updatedVisible.count == 1)
        #expect(updatedVisible[0].overlay.marketDataId == "ID_100")
    }

    @Test func partialMatchingOverlays() {
        // Given: Price data with IDs "ID_0" to "ID_4"
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Mix of matching and non-matching overlays
        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_0"),   // matches
            createTestMarkOverlay(marketDataId: "ID_99"),  // doesn't match
            createTestMarkOverlay(marketDataId: "ID_3"),   // matches
            createTestMarkOverlay(marketDataId: "ID_100"), // doesn't match
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Only matching overlays should be visible
        #expect(visible.count == 2)
        let visibleIds = Set(visible.map(\.overlay.marketDataId))
        #expect(visibleIds.contains("ID_0"))
        #expect(visibleIds.contains("ID_3"))
        #expect(!visibleIds.contains("ID_99"))
        #expect(!visibleIds.contains("ID_100"))
    }
}

// MARK: - Trade Overlay Filter Tests

struct PriceChartViewTradeOverlayFilterTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00

    @Test func tradesWithinTimestampRangeAreVisible() {
        // Given: Price data spanning 5 minutes
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Trade overlay within the timestamp range
        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(120)) // 2 minutes in
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Trade should be visible
        #expect(visible.count == 1)
    }

    @Test func tradesOutsideTimestampRangeAreFiltered() {
        // Given: Price data spanning 5 minutes starting at baseDate
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Trade overlays outside the timestamp range
        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(-60)),  // Before range
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(600)),  // After range (10 min)
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: No trades should be visible
        #expect(visible.isEmpty)
    }

    @Test func tradesWithEmptyIndexedDataReturnsEmpty() {
        // Given: Empty indexed data
        let indexedData: [IndexedPrice] = []

        // And: Trade overlays
        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate)
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: No trades should be visible
        #expect(visible.isEmpty)
    }

    @Test func tradeAtExactBoundaryIsVisible() {
        // Given: Price data with first timestamp at baseDate
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // And: Trade at exact start boundary
        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate) // Exact first timestamp
        ]

        // When: Filtering visible overlays
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Trade should be visible
        #expect(visible.count == 1)
    }

    @Test func tradeOverlayBecomesVisibleWhenDataLoaded() {
        // Scenario 3: Trade not in range initially, then becomes visible

        // Given: Trade overlay at a specific timestamp
        let tradeTimestamp = baseDate.addingTimeInterval(600) // 10 minutes after baseDate
        let tradeOverlays = [createTestTradeOverlay(timestamp: tradeTimestamp)]

        // And: Initially, indexed data does NOT include that timestamp range
        let initialData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60) // 0-2 minutes
                )
            )
        }

        // When: Filtering with initial data
        let initialVisible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: initialData,
            chartType: .candlestick
        )

        // Then: Trade should NOT be visible
        #expect(initialVisible.isEmpty)

        // And: Later, indexed data IS loaded with that timestamp range
        let updatedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index + 8) * 60) // 8-12 minutes
                )
            )
        }

        // When: Filtering with updated data
        let updatedVisible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: updatedData,
            chartType: .candlestick
        )

        // Then: Trade should now be visible
        #expect(updatedVisible.count == 1)
    }

    @Test func tradePriceUsesHighForCandlestick() {
        // Given: Price data with specific high value
        let indexedData = [
            createTestIndexedPrice(
                index: 0,
                data: createTestPriceData(id: "ID_0", date: baseDate, close: 100.0, high: 110.0)
            )
        ]

        // And: Trade overlay at that timestamp
        let tradeOverlays = [createTestTradeOverlay(timestamp: baseDate)]

        // When: Filtering with candlestick chart type
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .candlestick
        )

        // Then: Price should be the high value
        #expect(visible.count == 1)
        #expect(visible[0].price == 110.0)
    }

    @Test func tradePriceUsesCloseForLine() {
        // Given: Price data with specific close value
        let indexedData = [
            createTestIndexedPrice(
                index: 0,
                data: createTestPriceData(id: "ID_0", date: baseDate, close: 100.0, high: 110.0)
            )
        ]

        // And: Trade overlay at that timestamp
        let tradeOverlays = [createTestTradeOverlay(timestamp: baseDate)]

        // When: Filtering with line chart type
        let visible = PriceChartView.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: .line
        )

        // Then: Price should be the close value
        #expect(visible.count == 1)
        #expect(visible[0].price == 100.0)
    }
}

// MARK: - ViewInspector Rendering Tests

struct PriceChartViewRenderingTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00

    @MainActor
    @Test func chartRendersWithMarkOverlays() throws {
        // Given: Price data and matching mark overlays
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60),
                    close: 100.0 + Double(index),
                    high: 105.0 + Double(index)
                )
            )
        }

        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_1")
        ]

        // When: Creating the view
        var scrollPosition = 0
        let sut = PriceChartView(
            indexedData: indexedData,
            chartType: .candlestick,
            candlestickWidth: 8,
            yAxisDomain: 90...120,
            visibleCount: 3,
            isLoading: false,
            scrollPosition: .init(
                get: { scrollPosition },
                set: { scrollPosition = $0 }
            ),
            markOverlays: markOverlays
        )

        // Then: View should be inspectable (Chart is not directly inspectable via ViewInspector)
        #expect(throws: Never.self) { try sut.inspect() }
    }

    @MainActor
    @Test func chartRendersWithTradeOverlays() throws {
        // Given: Price data and trade overlays
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60),
                    close: 100.0 + Double(index),
                    high: 105.0 + Double(index)
                )
            )
        }

        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(60), isBuy: true)
        ]

        // When: Creating the view
        var scrollPosition = 0
        let sut = PriceChartView(
            indexedData: indexedData,
            chartType: .candlestick,
            candlestickWidth: 8,
            yAxisDomain: 90...120,
            visibleCount: 3,
            isLoading: false,
            scrollPosition: .init(
                get: { scrollPosition },
                set: { scrollPosition = $0 }
            ),
            tradeOverlays: tradeOverlays
        )

        // Then: View should be inspectable
        #expect(throws: Never.self) { try sut.inspect() }
    }

    @MainActor
    @Test func chartRendersWithoutOverlaysWhenNoneMatch() throws {
        // Given: Price data with no matching overlays
        let indexedData = (0..<3).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60),
                    close: 100.0 + Double(index),
                    high: 105.0 + Double(index)
                )
            )
        }

        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_99") // Non-matching
        ]

        // When: Creating the view
        var scrollPosition = 0
        let sut = PriceChartView(
            indexedData: indexedData,
            chartType: .candlestick,
            candlestickWidth: 8,
            yAxisDomain: 90...120,
            visibleCount: 3,
            isLoading: false,
            scrollPosition: .init(
                get: { scrollPosition },
                set: { scrollPosition = $0 }
            ),
            markOverlays: markOverlays
        )

        // Then: View should still render correctly
        #expect(throws: Never.self) { try sut.inspect() }
    }

    @MainActor
    @Test func chartRendersWithBothOverlayTypes() throws {
        // Given: Price data with both mark and trade overlays
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60),
                    close: 100.0 + Double(index),
                    high: 105.0 + Double(index)
                )
            )
        }

        let markOverlays = [
            createTestMarkOverlay(marketDataId: "ID_1"),
            createTestMarkOverlay(marketDataId: "ID_3"),
        ]

        let tradeOverlays = [
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(120), isBuy: true),
            createTestTradeOverlay(timestamp: baseDate.addingTimeInterval(180), isBuy: false),
        ]

        // When: Creating the view
        var scrollPosition = 0
        let sut = PriceChartView(
            indexedData: indexedData,
            chartType: .candlestick,
            candlestickWidth: 8,
            yAxisDomain: 90...120,
            visibleCount: 5,
            isLoading: false,
            scrollPosition: .init(
                get: { scrollPosition },
                set: { scrollPosition = $0 }
            ),
            tradeOverlays: tradeOverlays,
            markOverlays: markOverlays
        )

        // Then: View should render correctly with all overlays
        #expect(throws: Never.self) { try sut.inspect() }
    }
}

// MARK: - Find Closest Index Tests

struct PriceChartViewFindClosestIndexTests {
    let baseDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00

    @Test func findClosestIndexReturnsExactMatch() {
        // Given: Price data at specific timestamps
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // When: Finding index for exact timestamp
        let index = PriceChartView.findClosestIndex(
            for: baseDate.addingTimeInterval(120), // Exact match for index 2
            in: indexedData
        )

        // Then: Should return exact index
        #expect(index == 2)
    }

    @Test func findClosestIndexReturnsNearestWhenBetween() {
        // Given: Price data at 1-minute intervals
        let indexedData = (0..<5).map { index in
            createTestIndexedPrice(
                index: index,
                data: createTestPriceData(
                    id: "ID_\(index)",
                    date: baseDate.addingTimeInterval(Double(index) * 60)
                )
            )
        }

        // When: Finding index for timestamp between two data points
        let index = PriceChartView.findClosestIndex(
            for: baseDate.addingTimeInterval(90), // Between index 1 (60s) and index 2 (120s)
            in: indexedData
        )

        // Then: Should return the closer index (index 2 at 120s is 30s away, index 1 at 60s is also 30s away)
        // Binary search will find index 2, then compare with index 1
        #expect(index == 1 || index == 2)
    }

    @Test func findClosestIndexReturnsNilForEmptyData() {
        // Given: Empty indexed data
        let indexedData: [IndexedPrice] = []

        // When: Finding index
        let index = PriceChartView.findClosestIndex(for: baseDate, in: indexedData)

        // Then: Should return nil
        #expect(index == nil)
    }
}
