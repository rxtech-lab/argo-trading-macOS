//
//  PriceChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Charts
import SwiftUI

/// Trade overlay data for chart visualization
struct TradeOverlay: Identifiable {
    let id: String
    let index: Int
    let price: Double
    let isBuy: Bool
    let trade: Trade
}

/// Mark overlay data for chart visualization
struct MarkOverlay: Identifiable {
    let id: String
    let index: Int
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

    @Binding var scrollPosition: Int
    @Binding var selectedIndex: Int?

    var tradeOverlays: [TradeOverlay] = []
    var markOverlays: [MarkOverlay] = []

    /// Callback when scroll position changes
    var onScrollChange: ((Int) -> Void)?

    // Hover state for tooltips
    @State private var hoveredTrade: TradeOverlay?
    @State private var hoveredMark: MarkOverlay?

    private var maximumSelectedIndex: Int? {
        guard let selectedIndex = selectedIndex else { return nil }
        if selectedIndex < 5 {
            return 5
        }
        return min(selectedIndex, indexedData.count - 5)
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

            // Trade overlays (label + line + arrow)
            ForEach(tradeOverlays) { overlay in
                let lineOffset = tradeLineOffset(isBuy: overlay.isBuy)
                let lineStart = overlay.price + lineOffset

                // Label above the line
                PointMark(
                    x: .value("Index", overlay.index),
                    y: .value("Price", lineStart)
                )
                .annotation(position: overlay.isBuy ? .top : .bottom) {
                    Text(overlay.isBuy ? "BUY" : "SELL")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(overlay.isBuy ? .green : .red)
                        )
                }
                .symbolSize(0)

                // Vertical line extending from price
                RuleMark(
                    x: .value("Index", overlay.index),
                    yStart: .value("Start", lineStart),
                    yEnd: .value("End", overlay.price)
                )
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(overlay.isBuy ? .green : .red)

                // Arrow at the price point (pointing toward the bar)
                PointMark(
                    x: .value("Index", overlay.index),
                    y: .value("Price", overlay.price)
                )
                .symbol {
                    Image(systemName: overlay.isBuy ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                        .font(.system(size: 14))
                        .foregroundColor(overlay.isBuy ? .green : .red)
                }
            }

            // Mark overlays (shapes)
            ForEach(markOverlays) { overlay in
                PointMark(
                    x: .value("Index", overlay.index),
                    y: .value("Price", overlay.price)
                )
                .symbol {
                    markSymbol(for: overlay.mark)
                }
                .symbolSize(100)
            }

            // Selection indicator
            if let idx = maximumSelectedIndex {
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
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let idx = value.as(Int.self),
                       let item = indexedData.first(where: { $0.index == idx }) {
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
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $selectedIndex)
        .onChange(of: scrollPosition) { _, newIndex in
            onScrollChange?(newIndex)
        }
        .onChange(of: selectedIndex) { _, newIndex in
            // Update hovered trade/mark based on selection
            updateHoveredOverlays(at: newIndex)
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
        if let trade = tradeOverlays.first(where: { abs($0.index - index) <= tolerance }) {
            hoveredTrade = trade
            hoveredMark = nil
            return
        }

        // Check for mark at this index
        if let mark = markOverlays.first(where: { abs($0.index - index) <= tolerance }) {
            hoveredMark = mark
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
        let offset = range * 0.10  // 10% of visible range
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
        trade.orderType.lowercased().contains("buy")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isBuy ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .foregroundColor(isBuy ? .green : .red)
                Text(trade.orderType.uppercased())
                    .font(.caption.bold())
            }

            Divider()

            LabeledContent("Symbol", value: trade.symbol)
            LabeledContent("Position", value: trade.positionType)
            LabeledContent("Qty", value: String(format: "%.4f", trade.executedQty))
            LabeledContent("Price", value: String(format: "%.2f", trade.executedPrice))
            LabeledContent("PnL", value: String(format: "%.2f", trade.pnl))
                .foregroundColor(trade.pnl >= 0 ? .green : .red)

            if !trade.reason.isEmpty {
                Divider()
                Text(trade.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
