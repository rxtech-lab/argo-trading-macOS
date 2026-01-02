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
        localFromIndex < threshold
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

private struct ScrollChangeEvent: Equatable {
    let currentScrollIndex: Int
    let totalCount: Int
    let firstGlobalIndex: Int

    var localIndex: Int {
        currentScrollIndex - firstGlobalIndex
    }
}

/// Reusable price chart component that renders candlestick/line charts with optional overlays
struct PriceChartView: View {
    let data: [PriceData]
    let chartType: ChartType
    let candlestickWidth: CGFloat
    let visibleCount: Int
    let isLoading: Bool
    let initialScrollPosition: Int
    let totalDataCount: Int

    var tradeOverlays: [TradeOverlay] = []
    var markOverlays: [MarkOverlay] = []

    /// Visibility flags for overlay toggle controls
    var showTrades: Bool = true
    var showMarks: Bool = true

    /// Callback when scroll position changes
    /// Return a new index
    var onScrollChange: ((VisibleLogicalRange) async -> Void)?
    /// Callback when selection changes (for legend updates)
    var onSelectionChange: ((Int?) -> Void)?

    // Local selection state to avoid parent re-renders on every hover
    @State private var selectedIndex: Int?
    // Hover state for tooltips
    @State private var hoveredTrade: TradeOverlay?
    @State private var hoveredMark: MarkOverlay?
    // Debounce scroll changes
    @State private var scrollSubject = PassthroughSubject<ScrollChangeEvent, Never>()
    @State private var scrollCancellable: AnyCancellable?
    @State private var scrollPositionInternal: Int = 0
    @State private var yAxisDomain: ClosedRange<Double> = 0...1
    // Debounce Y-axis domain updates
    @State private var yAxisSubject = PassthroughSubject<[PriceData], Never>()
    @State private var yAxisCancellable: AnyCancellable?

    // MARK: - Computed Overlay Indices

    /// Compute trade overlay indices and prices on-demand using binary search
    private var visibleTradeOverlays: [(overlay: TradeOverlay, index: Int, price: Double)] {
        guard !data.isEmpty else { return [] }
        return tradeOverlays.compactMap { overlay in
            if let index = findClosestIndex(for: overlay.timestamp),
               let priceData = data.first(where: { $0.globalIndex == index })
            {
                let price = chartType == .candlestick ? priceData.high : priceData.close
                return (overlay, index, price)
            }
            return nil
        }
    }

    /// Compute mark overlay indices using signal timestamp to find closest data point
    private var visibleMarkOverlays: [(overlay: MarkOverlay, index: Int, price: Double)] {
        guard !data.isEmpty else { return [] }
        return markOverlays.compactMap { overlay in
            if let index = findClosestIndex(for: overlay.mark.signal.time),
               let priceData = data.first(where: { $0.globalIndex == index })
            {
                let basePrice = chartType == .candlestick ? priceData.low : priceData.close
                let price = basePrice + markVerticalOffset()
                return (overlay, index, price)
            }
            return nil
        }
    }

    /// Binary search to find closest index for a given timestamp
    private func findClosestIndex(for date: Date) -> Int? {
        guard !data.isEmpty else { return nil }

        var low = 0
        var high = data.count - 1

        while low < high {
            let mid = (low + high) / 2
            if data[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Check if the found index or its neighbor is closer
        if low > 0 {
            let diffLow = abs(data[low].date.timeIntervalSince(date))
            let diffPrev = abs(data[low - 1].date.timeIntervalSince(date))
            if diffPrev < diffLow {
                return data[low - 1].globalIndex
            }
        }

        return data[low].globalIndex
    }

    /// Adjust overlay index to avoid edge clipping
    /// Shifts index inward if at boundaries so overlays remain visible
    private func adjustedIndexForDisplay(_ index: Int) -> Int {
        guard data.count > 2 else { return index }
        let maxIndex = data.count - 1
        if index < 1 {
            return 1
        } else if index >= maxIndex {
            return maxIndex - 1
        }
        return index
    }

    /// Calculate vertical offset for marks to avoid overlap with trades on line charts
    /// Returns negative offset (moves marks below the close price)
    private func markVerticalOffset() -> Double {
        // Only apply offset on line charts when both trades and marks are visible
        guard chartType == .line && showTrades && showMarks && !tradeOverlays.isEmpty else { return 0 }
        guard let minPrice = data.map(\.low).min(),
              let maxPrice = data.map(\.high).max() else { return 0 }
        let range = maxPrice - minPrice
        return -range * 0.03 // 3% of visible range, negative to go below
    }

    // MARK: - Chart Content Components

    @ChartContentBuilder
    private var priceDataMarks: some ChartContent {
        ForEach(data) { item in
            if chartType == .line {
                LineMark(
                    x: .value("Index", item.globalIndex),
                    y: .value("Close", item.close)
                )
                .foregroundStyle(.blue)
            } else {
                candlestickMarks(for: item)
            }
        }
    }

    @ChartContentBuilder
    private func candlestickMarks(for item: PriceData) -> some ChartContent {
        let isGreen = item.close >= item.open

        RectangleMark(
            x: .value("Index", item.globalIndex),
            yStart: .value("Open", item.open),
            yEnd: .value("Close", item.close),
            width: .fixed(candlestickWidth)
        )
        .foregroundStyle(isGreen ? .green : .red)

        RuleMark(
            x: .value("Index", item.globalIndex),
            yStart: .value("Low", item.low),
            yEnd: .value("High", item.high)
        )
        .foregroundStyle(isGreen ? .green : .red)
        .lineStyle(StrokeStyle(lineWidth: max(1, candlestickWidth / 6)))
    }

    @ChartContentBuilder
    private var tradeOverlayMarks: some ChartContent {
        if showTrades {
            ForEach(visibleTradeOverlays, id: \.overlay.id) { item in
                tradePointMark(for: item)
            }
        }
    }

    @ChartContentBuilder
    private func tradePointMark(
        for item: (overlay: TradeOverlay, index: Int, price: Double)
    ) -> some ChartContent {
        let overlay = item.overlay
        let displayIndex = adjustedIndexForDisplay(item.index)

        PointMark(
            x: .value("Index", displayIndex),
            y: .value("Price", item.price)
        )
        .symbolSize(10)
        .foregroundStyle(.red)
        .annotation(position: overlay.isBuy ? .top : .bottom) {
            tradeLabel(isBuy: overlay.isBuy)
        }
    }

    @ViewBuilder
    private func tradeLabel(isBuy: Bool) -> some View {
        Text(isBuy ? "B" : "S")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isBuy ? .green : .red)
            )
    }

    @ChartContentBuilder
    private var markOverlayMarks: some ChartContent {
        if showMarks {
            ForEach(visibleMarkOverlays, id: \.overlay.id) { item in
                PointMark(
                    x: .value("Index", adjustedIndexForDisplay(item.index)),
                    y: .value("Price", item.price)
                )
                .symbol {
                    markSymbol(for: item.overlay.mark)
                }
                .symbolSize(200)
            }
        }
    }

    @ChartContentBuilder
    private var selectionIndicatorMark: some ChartContent {
        if let idx = selectedIndex, idx >= scrollPositionInternal {
            RuleMark(x: .value("Selected", idx))
                .foregroundStyle(.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .annotation(position: .top, alignment: .center) {
                    selectionAnnotation(for: idx)
                }
        }
    }

    @ViewBuilder
    private func selectionAnnotation(for idx: Int) -> some View {
        if let item = data.first(where: { $0.globalIndex == idx }) {
            Text(item.close, format: .number.precision(.fractionLength(2)))
                .font(.caption2)
                .padding(4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var xAxisDomain: ClosedRange<Int> {
        guard totalDataCount > 0 else {
            return 0...1
        }
        return 0...(totalDataCount - 1)
    }

    private func updateYAxisDomain(data: [PriceData]) {
        guard !data.isEmpty else {
            yAxisDomain = 0...1
            return
        }

        let minY: Double
        let maxY: Double

        if chartType == .candlestick {
            minY = data.map(\.low).min() ?? 0
            maxY = data.map(\.high).max() ?? 1
        } else {
            minY = data.map(\.close).min() ?? 0
            maxY = data.map(\.close).max() ?? 1
        }

        let padding = (maxY - minY) * 0.05
        yAxisDomain = (minY - padding)...(maxY + padding)
    }

    // MARK: - Body

    var body: some View {
        chart
            .overlay(alignment: .topTrailing) {
                tooltipView
            }
    }

    private var chart: some View {
        Chart {
            priceDataMarks
            tradeOverlayMarks
            markOverlayMarks
            selectionIndicatorMark
        }
        .chartXScale(domain: xAxisDomain)
        .chartYScale(domain: yAxisDomain)
        .chartXAxis { xAxisContent }
        .chartYAxis { yAxisContent }
        .chartScrollableAxes([.horizontal])
        .chartXVisibleDomain(length: visibleCount)
        .chartScrollPosition(x: $scrollPositionInternal)
        .chartXSelection(value: $selectedIndex)
        .onAppear {
            setupScrollSubscription()
            setupYAxisSubscription()
            updateYAxisDomain(data: data)
        }
        .onChange(of: data) { _, newData in
            yAxisSubject.send(newData)
        }
        .onChange(of: scrollPositionInternal) { _, newValue in
            let firstIndex = data.first?.globalIndex ?? 0
            logger.debug("Scroll position changed to \(newValue), firstGlobalIndex: \(firstIndex)")
            if newValue != initialScrollPosition && newValue > 0 {
                scrollSubject.send(ScrollChangeEvent(currentScrollIndex: newValue, totalCount: data.count, firstGlobalIndex: firstIndex))
            }
        }
        .onChange(of: selectedIndex) { _, newIndex in
            updateHoveredOverlays(at: newIndex)
            onSelectionChange?(newIndex)
        }
        .onChange(of: initialScrollPosition) { _, newValue in
            let firstIndex = data.first?.globalIndex ?? 0
            logger.debug("Initial scroll position changed to \(newValue), globalNewIndex: \(firstIndex), scrolling chart...")
            withAnimation {
                scrollPositionInternal = newValue
            }
        }
        .chartScrollTargetBehavior(
            .valueAligned(
                unit: 1,
                majorAlignment: .page
            )
        )
    }

    private var xAxisContent: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine()
            AxisValueLabel {
                if let idx = value.as(Int.self),
                   let item = data.first(where: { $0.globalIndex == idx })
                {
                    Text(item.date, format: .dateTime.year().month().day().hour().minute())
                }
            }
        }
    }

    private var yAxisContent: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine()
            AxisValueLabel {
                if let doubleValue = value.as(Double.self) {
                    Text(doubleValue, format: .number.precision(.fractionLength(2)))
                }
            }
        }
    }

    private func setupScrollSubscription() {
        scrollCancellable = scrollSubject
            .removeDuplicates()
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { event in
                Task {
                    let visableRange = VisibleLogicalRange(globalFromIndex: event.currentScrollIndex, localFromIndex: event.localIndex, globalToIndex: event.currentScrollIndex + visibleCount, localToIndex: event.localIndex + visibleCount, totalCount: event.totalCount)
                    logger.debug("Event scroll to index: \(event.currentScrollIndex), isClostToBegining: \(visableRange.isNearStart()), isCloseToEnd: \(visableRange.isNearEnd())")
                    await onScrollChange?(visableRange)
                }
            }
    }

    private func setupYAxisSubscription() {
        yAxisCancellable = yAxisSubject
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { data in
                withAnimation {
                    updateYAxisDomain(data: data)
                }
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
        let color = mark.color.toColor()
        let letter = String(mark.title.prefix(1))
        let size: CGFloat = 16

        switch mark.shape {
        case .circle:
            ZStack {
                Circle()
                    .fill(color)
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .square:
            ZStack {
                Rectangle()
                    .fill(color)
                Text(letter)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
        case .triangle:
            ZStack {
                Image(systemName: "triangle.fill")
                    .font(.system(size: size))
                    .foregroundColor(color)
                Text(letter)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: 2)
            }
        }
    }

    private func tradeLineOffset(isBuy: Bool) -> Double {
        guard let minPrice = data.map(\.low).min(),
              let maxPrice = data.map(\.high).max() else { return 0 }
        let range = maxPrice - minPrice
        let offset = range * 0.10 // 10% of visible range
        return isBuy ? offset : -offset
    }

    /// Determine annotation position for marks based on trade visibility
    /// Places marks below when trades are visible on line charts to avoid overlap
    private func markAnnotationPosition() -> AnnotationPosition {
        if chartType == .line && showTrades && !tradeOverlays.isEmpty {
            return .bottom
        }
        return .top
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
                Text("Message:")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(mark.message)
                    .font(.caption2)
            }

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Signal: \(mark.signal.type.rawValue)")
                    .font(.caption2)
                if !mark.signal.reason.isEmpty {
                    Text(mark.signal.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
        let color = mark.color.toColor()

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
