//
//  PriceChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/21/25.
//

import Charts
import SwiftUI

enum ChartType: String, CaseIterable, Identifiable {
    case line = "Line"
    case candlestick = "Candlestick"

    var id: String { rawValue }
}

struct PriceChartView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(\.dismiss) private var dismiss

    @State private var chartType: ChartType = .candlestick
    @State private var loadedData: [PriceData] = []
    @State private var totalCount: Int = 0
    @State private var currentOffset: Int = 0
    @State private var isLoading = false
    @State private var selectedDate: Date?
    @State private var scrollPosition: Date = .init()
    @State private var zoomScale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Buffer configuration
    private let baseVisibleCount = 100
    private let bufferSize = 300 // Load 3x visible for buffer
    private let minZoom: CGFloat = 0.1 // Show more data (zoom out)
    private let maxZoom: CGFloat = 5.0 // Show less data (zoom in)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            legendView

            if loadedData.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Load a dataset to view the chart")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading && loadedData.isEmpty {
                ProgressView("Loading chart data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                chartContent
            }

            scrollInfoView
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 500)
        .task {
            await loadInitialData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Price Chart")
                .font(.headline)

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        zoomScale = max(minZoom, zoomScale / 1.5)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption)
                    .frame(width: 40)

                Button {
                    withAnimation {
                        zoomScale = min(maxZoom, zoomScale * 1.5)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Button {
                    withAnimation {
                        zoomScale = 1.0
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(zoomScale == 1.0)
            }

            Divider()
                .frame(height: 20)

            Picker("", selection: $chartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
    }

    // MARK: - Legend (shows OHLCV on hover)

    private var legendView: some View {
        Group {
            if let date = selectedDate, let item = findPriceData(for: date) {
                HStack(spacing: 16) {
                    Text(item.date, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(.secondary)

                    Group {
                        LegendItem(label: "O", value: item.open, color: .primary)
                        LegendItem(label: "H", value: item.high, color: .green)
                        LegendItem(label: "L", value: item.low, color: .red)
                        LegendItem(label: "C", value: item.close, color: item.close >= item.open ? .green : .red)
                        LegendItem(label: "V", value: item.volume, color: .blue, decimals: 0)
                    }
                }
                .font(.system(.body, design: .monospaced))
            } else {
                Text("Hover over chart to see values")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 24)
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        let chart = Chart {
            ForEach(sortedData) { item in
                switch chartType {
                case .line:
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Close", item.close)
                    )
                    .foregroundStyle(.blue)
                case .candlestick:
                    // Candlestick body
                    RectangleMark(
                        x: .value("Date", item.date),
                        yStart: .value("Open", item.open),
                        yEnd: .value("Close", item.close),
                        width: .fixed(candlestickWidth)
                    )
                    .foregroundStyle(item.close >= item.open ? .green : .red)

                    // Candlestick wick
                    RuleMark(
                        x: .value("Date", item.date),
                        yStart: .value("Low", item.low),
                        yEnd: .value("High", item.high)
                    )
                    .foregroundStyle(item.close >= item.open ? .green : .red)
                    .lineStyle(StrokeStyle(lineWidth: max(1, candlestickWidth / 6)))
                }
            }

            // Crosshair vertical line at selected position
            if let selectedDate = selectedDate {
                RuleMark(x: .value("Selected", selectedDate))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .center) {
                        if let item = findPriceData(for: selectedDate) {
                            Text(item.close, format: .number.precision(.fractionLength(2)))
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month().day().hour().minute())
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
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleTimeInterval)
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $selectedDate)
        .onChange(of: scrollPosition) { _, newPosition in
            Task {
                await checkAndLoadMoreData(around: newPosition)
            }
        }

        chart
            .gesture(magnificationGesture)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyBy) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newScale = zoomScale * value.magnification
                zoomScale = min(max(newScale, minZoom), maxZoom)
            }
    }

    // MARK: - Scroll Info

    private var scrollInfoView: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading more data...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Showing \(loadedData.count) of \(totalCount) records")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("• Scroll to navigate, pinch to zoom")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Computed Properties

    private var sortedData: [PriceData] {
        loadedData.sorted { $0.date < $1.date }
    }

    private var yAxisDomain: ClosedRange<Double> {
        guard !loadedData.isEmpty else { return 0...100 }

        let minY = loadedData.map(\.low).min() ?? 0
        let maxY = loadedData.map(\.high).max() ?? 100
        let range = maxY - minY
        let padding = max(range * 0.05, 0.01) // At least some padding

        return (minY - padding)...(maxY + padding)
    }

    private var visibleCount: Int {
        // Adjust visible count based on zoom scale
        // Higher zoom = fewer candles (zoom in), lower zoom = more candles (zoom out)
        let scale = max(0.01, zoomScale * magnifyBy) // Prevent division by zero/tiny numbers
        let adjustedCount = Double(baseVisibleCount) / scale

        // Guard against NaN/infinity and clamp to reasonable range
        // Max 200 candles to prevent overcrowding when zoomed out
        guard adjustedCount.isFinite else { return baseVisibleCount }
        return min(max(10, Int(adjustedCount)), 200)
    }

    private var candlestickWidth: CGFloat {
        // Adjust candlestick width based on zoom
        // Wider candles when zoomed in, thinner when zoomed out
        let scale = max(0.1, zoomScale * magnifyBy)
        let baseWidth: CGFloat = 6
        return max(2, min(baseWidth * scale, 20)) // Clamp between 2 and 20
    }

    private var visibleTimeInterval: TimeInterval {
        // Show approximately visibleCount candles
        // Assuming 1-minute data, adjust multiplier based on your data frequency
        guard sortedData.count >= 2 else { return 3600 * 6 } // Default 6 hours

        let first = sortedData[0].date
        let second = sortedData[1].date
        let candleInterval = second.timeIntervalSince(first)

        return candleInterval * Double(visibleCount)
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            try dbService.initDatabase()
            totalCount = try await dbService.getTotalCount(for: url)

            // Start from the end (most recent data) and load buffer
            let startOffset = max(0, totalCount - bufferSize)
            currentOffset = startOffset

            let loadedDataInMemory = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: startOffset,
                count: bufferSize
            )
            withAnimation {
                loadedData = loadedDataInMemory
            }

            // Set initial scroll position to show recent data
            if let lastDate = sortedData.last?.date {
                scrollPosition = lastDate
            }
        } catch {
            alertManager.showAlert(message: error.localizedDescription)
        }

        isLoading = false
    }

    private func checkAndLoadMoreData(around date: Date) async {
        guard !isLoading, !loadedData.isEmpty else { return }

        let sorted = sortedData
        guard let firstDate = sorted.first?.date,
              let lastDate = sorted.last?.date else { return }

        let totalRange = lastDate.timeIntervalSince(firstDate)
        let positionFromStart = date.timeIntervalSince(firstDate)
        let positionRatio = totalRange > 0 ? positionFromStart / totalRange : 0.5

        // Load more at the beginning if scrolled to first 20%
        if positionRatio < 0.2 && currentOffset > 0 {
            await loadMoreAtBeginning()
        }

        // Load more at the end if scrolled to last 20%
        if positionRatio > 0.8 && currentOffset + loadedData.count < totalCount {
            await loadMoreAtEnd()
        }
    }

    private func loadMoreAtBeginning() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let loadCount = min(bufferSize / 2, currentOffset)
            let newOffset = currentOffset - loadCount

            let newData = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: newOffset,
                count: loadCount
            )

            // Prepend new data and trim from end if buffer too large
            loadedData = newData + loadedData
            currentOffset = newOffset

            // Trim excess from end
            if loadedData.count > bufferSize * 2 {
                loadedData = Array(loadedData.prefix(bufferSize * 2))
            }
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    private func loadMoreAtEnd() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let currentEnd = currentOffset + loadedData.count
            let loadCount = min(bufferSize / 2, totalCount - currentEnd)

            let newData = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: currentEnd,
                count: loadCount
            )

            // Append new data and trim from beginning if buffer too large
            loadedData = loadedData + newData

            // Trim excess from beginning
            if loadedData.count > bufferSize * 2 {
                let trimCount = loadedData.count - bufferSize * 2
                loadedData = Array(loadedData.dropFirst(trimCount))
                currentOffset += trimCount
            }
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func findPriceData(for date: Date) -> PriceData? {
        // Find closest price data to the selected date
        sortedData.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

// MARK: - Legend Item Component

private struct LegendItem: View {
    let label: String
    let value: Double
    let color: Color
    var decimals: Int = 2

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(decimals)))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    PriceChartView(url: URL(fileURLWithPath: "/tmp/test.parquet"))
        .environment(DuckDBService())
        .environment(AlertManager())
}
