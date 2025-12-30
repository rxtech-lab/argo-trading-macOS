//
//  PriceChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Charts
import Combine
import SwiftUI

/// Represents the visible logical range of the chart (similar to lightweight-charts)
struct VisibleLogicalRange {
    let from: Int // Start index of visible range (scroll position)
    let to: Int // End index of visible range (from + visibleCount)
    let visibleCount: Int // Number of visible bars
    let totalCount: Int // Total data points in chart

    /// Distance from the beginning (negative if scrolled past start)
    var distanceFromStart: Int { from }

    /// Distance from the end
    var distanceFromEnd: Int { totalCount - to }

    /// Whether near the start (within threshold)
    func isNearStart(threshold: Int = 10) -> Bool {
        from < threshold
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
    let marketDataId: String
    let price: Double
    let mark: Mark
}

/// Reusable price chart component that renders candlestick/line charts with optional overlays
struct PriceChartView: View {
    let indexedData: [IndexedPrice]
    let chartType: ChartType
    let candlestickWidth: CGFloat
    let yAxisDomain: ClosedRange<Double>
    let visibleCount: Int
    let isLoading: Bool

    @Binding var scrollPosition: Int

    var tradeOverlays: [TradeOverlay] = []
    var markOverlays: [MarkOverlay] = []

    /// Callback when scroll position changes
    var onScrollChange: ((VisibleLogicalRange) -> Void)?
    /// Callback when selection changes (for legend updates)
    var onSelectionChange: ((Int?) -> Void)?

    // Local selection state to avoid parent re-renders on every hover
    @State private var selectedIndex: Int?
    // Hover state for tooltips
    @State private var hoveredTrade: TradeOverlay?
    @State private var hoveredMark: MarkOverlay?
    // Debounce scroll changes
    @State private var scrollSubject = PassthroughSubject<Int, Never>()
    @State private var scrollCancellable: AnyCancellable?

    // MARK: - Computed Overlay Indices (lazy computation)

    /// Get the timestamp range of loaded data for filtering overlays
    private var dataTimestampRange: ClosedRange<Date>? {
        guard let first = indexedData.first?.data.date,
              let last = indexedData.last?.data.date
        else {
            return nil
        }
        return first ... last
    }

    /// Compute trade overlay indices and prices on-demand using binary search
    private var visibleTradeOverlays: [(overlay: TradeOverlay, index: Int, price: Double)] {
        Self.filterVisibleTradeOverlays(
            tradeOverlays: tradeOverlays,
            indexedData: indexedData,
            chartType: chartType
        )
    }

    /// Compute mark overlay indices on-demand by matching marketDataId
    private var visibleMarkOverlays: [(overlay: MarkOverlay, index: Int, price: Double)] {
        Self.filterVisibleMarkOverlays(
            markOverlays: markOverlays,
            indexedData: indexedData,
            chartType: chartType
        )
    }

    // MARK: - Static Filter Methods (for testing)

    /// Filter mark overlays to only include those with matching market data IDs
    /// - Parameters:
    ///   - markOverlays: The mark overlays to filter
    ///   - indexedData: The loaded price data with indices
    ///   - chartType: The chart type (affects which price is used)
    /// - Returns: Visible overlays with their index and price
    static func filterVisibleMarkOverlays(
        markOverlays: [MarkOverlay],
        indexedData: [IndexedPrice],
        chartType: ChartType
    ) -> [(overlay: MarkOverlay, index: Int, price: Double)] {
        guard !indexedData.isEmpty else { return [] }
        // Create lookup dictionary for O(1) access - use high price for candlestick, close for line
        let dataById = Dictionary(
            indexedData.map { item in
                let price = chartType == .candlestick ? item.data.high : item.data.close
                return (item.data.id, (item.index, price))
            },
            uniquingKeysWith: { first, _ in first }
        )
        return markOverlays.compactMap { overlay in
            if let (index, price) = dataById[overlay.marketDataId] {
                return (overlay, index, price)
            }
            return nil
        }
    }

    /// Filter trade overlays to only include those within the data timestamp range
    /// - Parameters:
    ///   - tradeOverlays: The trade overlays to filter
    ///   - indexedData: The loaded price data with indices
    ///   - chartType: The chart type (affects which price is used)
    /// - Returns: Visible overlays with their index and price
    static func filterVisibleTradeOverlays(
        tradeOverlays: [TradeOverlay],
        indexedData: [IndexedPrice],
        chartType: ChartType
    ) -> [(overlay: TradeOverlay, index: Int, price: Double)] {
        guard !indexedData.isEmpty,
              let first = indexedData.first?.data.date,
              let last = indexedData.last?.data.date
        else { return [] }

        let timestampRange = first ... last

        return tradeOverlays.compactMap { overlay in
            // Skip trades outside the data timestamp range
            guard timestampRange.contains(overlay.timestamp) else { return nil }

            if let index = findClosestIndex(for: overlay.timestamp, in: indexedData),
               let data = indexedData.first(where: { $0.index == index })
            {
                let price = chartType == .candlestick ? data.data.high : data.data.close
                return (overlay, index, price)
            }
            return nil
        }
    }

    /// Binary search to find closest index for a given timestamp (static version for testing)
    static func findClosestIndex(for date: Date, in indexedData: [IndexedPrice]) -> Int? {
        guard !indexedData.isEmpty else { return nil }

        var low = 0
        var high = indexedData.count - 1

        while low < high {
            let mid = (low + high) / 2
            if indexedData[mid].data.date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Check if the found index or its neighbor is closer
        if low > 0 {
            let diffLow = abs(indexedData[low].data.date.timeIntervalSince(date))
            let diffPrev = abs(indexedData[low - 1].data.date.timeIntervalSince(date))
            if diffPrev < diffLow {
                return indexedData[low - 1].index
            }
        }

        return indexedData[low].index
    }

    /// Binary search to find closest index for a given timestamp
    private func findClosestIndex(for date: Date) -> Int? {
        guard !indexedData.isEmpty else { return nil }

        var low = 0
        var high = indexedData.count - 1

        while low < high {
            let mid = (low + high) / 2
            if indexedData[mid].data.date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Check if the found index or its neighbor is closer
        if low > 0 {
            let diffLow = abs(indexedData[low].data.date.timeIntervalSince(date))
            let diffPrev = abs(indexedData[low - 1].data.date.timeIntervalSince(date))
            if diffPrev < diffLow {
                return indexedData[low - 1].index
            }
        }

        return indexedData[low].index
    }

    /// Adjust overlay index to avoid edge clipping
    /// Shifts index inward if at boundaries so overlays remain visible
    private func adjustedIndexForDisplay(_ index: Int) -> Int {
        guard indexedData.count > 2 else { return index }
        let maxIndex = indexedData.count - 1
        if index < 1 {
            return 1
        } else if index >= maxIndex {
            return maxIndex - 1
        }
        return index
    }

    var body: some View {
        Chart {
            // Price data
            ForEach(indexedData) { item in
                switch chartType {
                case .line:
                    LineMark(
                        x: .value("Index", item.index),
                        y: .value("Close", item.data.close)
                    )
                    .foregroundStyle(.blue)
                case .candlestick:
                    RectangleMark(
                        x: .value("Index", item.index),
                        yStart: .value("Open", item.data.open),
                        yEnd: .value("Close", item.data.close),
                        width: .fixed(candlestickWidth)
                    )
                    .foregroundStyle(item.data.close >= item.data.open ? .green : .red)

                    RuleMark(
                        x: .value("Index", item.index),
                        yStart: .value("Low", item.data.low),
                        yEnd: .value("High", item.data.high)
                    )
                    .foregroundStyle(item.data.close >= item.data.open ? .green : .red)
                    .lineStyle(StrokeStyle(lineWidth: max(1, candlestickWidth / 6)))
                }
            }

            // Trade overlays (label + line + arrow) - computed lazily
            ForEach(visibleTradeOverlays, id: \.overlay.id) { item in
                let overlay = item.overlay
                let displayIndex = adjustedIndexForDisplay(item.index)

                // Label above the line
                PointMark(
                    x: .value("Index", displayIndex),
                    y: .value("Price", item.price)
                )
                .symbolSize(10)
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .annotation(position: overlay.isBuy ? .top : .bottom) {
                    Text(overlay.isBuy ? "B" : "S")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(overlay.isBuy ? .green : .red)
                        )
                }
            }

            // Mark overlays (shapes) - computed lazily
            ForEach(visibleMarkOverlays, id: \.overlay.id) { item in
                PointMark(
                    x: .value("Index", adjustedIndexForDisplay(item.index)),
                    y: .value("Price", item.price)
                )
                .symbol {
                    markSymbol(for: item.overlay.mark)
                }
                .symbolSize(100)
            }

            // Selection indicator
            if let idx = selectedIndex, idx >= scrollPosition {
                RuleMark(x: .value("Selected", idx))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .center) {
                        if let item = indexedData.first(where: { $0.index == idx }) {
                            Text(item.data.close, format: .number.precision(.fractionLength(2)))
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXScale(domain: 0 ... (max(1, indexedData.count) - 1))
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let idx = value.as(Int.self),
                       let item = indexedData.first(where: { $0.index == idx })
                    {
                        Text(item.data.date, format: .dateTime.year().month().day().hour().minute())
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(doubleValue, format: .number.precision(.fractionLength(2)))
                    }
                }
            }
        }
        .chartScrollableAxes([.horizontal])
        .chartXVisibleDomain(length: visibleCount)
        .chartScrollPosition(x: Binding(get: {
            scrollPosition
        }, set: { newValue in
            if newValue >= 0 {
                scrollPosition = newValue
            }
        }))
        .chartXSelection(value: Binding(get: {
            selectedIndex
        }, set: { newValue in
            if let newValue = newValue {
                if newValue >= 0 {
                    selectedIndex = newValue
                }
            } else {
                selectedIndex = nil
            }
        }))
        .onChange(of: scrollPosition) { oldIndex, newIndex in
            if newIndex != oldIndex && newIndex >= 0 && !isLoading {
                scrollSubject.send(newIndex)
            }
        }
        .onAppear {
            scrollCancellable = scrollSubject
                .removeDuplicates()
                .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
                .sink { newIndex in
                    print("New index: \(newIndex)")
                    let range = VisibleLogicalRange(
                        from: newIndex,
                        to: newIndex + visibleCount,
                        visibleCount: visibleCount,
                        totalCount: indexedData.count
                    )
                    onScrollChange?(range)
                }
        }
        .onChange(of: selectedIndex) { _, newIndex in
            // Update hovered trade/mark based on selection
            updateHoveredOverlays(at: newIndex)
            // Notify parent for legend updates
            onSelectionChange?(newIndex)
        }
        .overlay(alignment: .topTrailing) {
            tooltipView
        }
    }

    // MARK: - Hover/Selection Handling

    private func updateHoveredOverlays(at index: Int?) {
        guard let index = index else {
            hoveredTrade = nil
            hoveredMark = nil
            return
        }

        // Check for trade at this index (within tolerance)
        let tolerance = 3
        if let tradeItem = visibleTradeOverlays.first(where: { abs($0.index - index) <= tolerance }) {
            hoveredTrade = tradeItem.overlay
            hoveredMark = nil
            return
        }

        // Check for mark at this index (tuple now includes price)
        if let markItem = visibleMarkOverlays.first(where: { abs($0.index - index) <= tolerance }) {
            hoveredMark = markItem.overlay
            hoveredTrade = nil
            return
        }

        hoveredTrade = nil
        hoveredMark = nil
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func markSymbol(for mark: Mark) -> some View {
        let color = Color(hex: mark.color) ?? .blue

        switch mark.shape {
        case .circle:
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        case .square:
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)
        case .triangle:
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundColor(color)
        }
    }

    private func tradeLineOffset(isBuy: Bool) -> Double {
        let range = yAxisDomain.upperBound - yAxisDomain.lowerBound
        let offset = range * 0.10 // 10% of visible range
        return isBuy ? offset : -offset
    }

    @ViewBuilder
    private var tooltipView: some View {
        if let trade = hoveredTrade {
            TradeTooltipView(trade: trade.trade)
                .padding(8)
        } else if let mark = hoveredMark {
            MarkTooltipView(mark: mark.mark)
                .padding(8)
        }
    }
}

// MARK: - Tooltip Views

private struct TradeTooltipView: View {
    let trade: Trade

    private var isBuy: Bool {
        trade.side == .buy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isBuy ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .foregroundColor(isBuy ? .green : .red)
                Text(trade.side.rawValue.uppercased())
                    .font(.caption.bold())
            }

            Divider()

            LabeledContent("Symbol", value: trade.symbol)
            LabeledContent("Position", value: trade.positionType)
            if let date = trade.executedAt {
                LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .standard))
            }
            LabeledContent("Qty", value: String(format: "%.4f", trade.executedQty))
            LabeledContent("Price", value: String(format: "%.2f", trade.executedPrice))
            if trade.side == .sell {
                LabeledContent("PnL", value: String(format: "%.2f", trade.pnl))
                    .foregroundColor(trade.pnl >= 0 ? .green : .red)
            }

            if !trade.reason.isEmpty {
                Divider()
                Text(trade.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(8)
        .glassEffect(in: .rect(cornerRadius: 12))
        .frame(maxWidth: 200)
    }
}

private struct MarkTooltipView: View {
    let mark: Mark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                markIcon
                Text(mark.title)
                    .font(.caption.bold())
            }

            if !mark.category.isEmpty {
                Text(mark.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mark.message.isEmpty {
                Divider()
                Text(mark.message)
                    .font(.caption2)
            }

            if let signal = mark.signal {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Signal: \(signal.type.rawValue)")
                        .font(.caption2)
                    if !signal.reason.isEmpty {
                        Text(signal.reason)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .font(.caption)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 200)
    }

    @ViewBuilder
    private var markIcon: some View {
        let color = Color(hex: mark.color) ?? .blue

        switch mark.shape {
        case .circle:
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        case .square:
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
        case .triangle:
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(color)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r, g, b, a: Double
        switch hexSanitized.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
