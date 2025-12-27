//
//  BacktestChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Charts
import SwiftUI

/// Chart view for backtest results with trade and mark overlays
struct BacktestChartView: View {
    let dataFilePath: String
    let tradesFilePath: String
    let marksFilePath: String

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager

    @State private var viewModel: PriceChartViewModel?
    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var zoomScale: CGFloat = 1.0
    @State private var scrollPosition: Int = 0
    @State private var loadDataTask: Task<Void, Never>?
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Overlay data
    @State private var trades: [Trade] = []
    @State private var marks: [Mark] = []
    @State private var tradeOverlays: [TradeOverlay] = []
    @State private var markOverlays: [MarkOverlay] = []

    // Zoom configuration
    private let baseVisibleCount = 100
    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 5.0

    private var dataURL: URL {
        URL(fileURLWithPath: dataFilePath)
    }

    private var tradesURL: URL {
        URL(fileURLWithPath: tradesFilePath)
    }

    private var marksURL: URL {
        URL(fileURLWithPath: marksFilePath)
    }

    /// Available time intervals filtered based on the original data timespan
    private var availableIntervals: [ChartTimeInterval] {
        ChartTimeInterval.filtered(for: dataURL)
    }

    private var visibleCount: Int {
        let scale = max(0.01, zoomScale * magnifyBy)
        let adjustedCount = Double(baseVisibleCount) / scale
        guard adjustedCount.isFinite else { return baseVisibleCount }
        return min(max(10, Int(adjustedCount)), 200)
    }

    private var candlestickWidth: CGFloat {
        let scale = max(0.1, zoomScale * magnifyBy)
        let baseWidth: CGFloat = 6
        return max(2, min(baseWidth * scale, 20))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            legendView

            if let vm = viewModel {
                if vm.loadedData.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("No price data available")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.isLoading && vm.loadedData.isEmpty {
                    ProgressView("Loading chart data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    chartContent
                }
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            scrollInfoView

            Divider()

            chartControlsView
        }
        .padding()
        .task {
            await initializeViewModel()
            await loadOverlayData()
        }
        .onChange(of: viewModel?.scrollPositionIndex) { _, newValue in
            if let newValue, newValue != scrollPosition {
                scrollPosition = newValue
            }
        }
        .onChange(of: viewModel?.sortedData) { _, _ in
            // Rebuild overlays when price data changes (e.g., during scroll/load)
            buildOverlays()
        }
        .gesture(magnificationGesture)
    }

    // MARK: - Initialization

    private func initializeViewModel() async {
        let vm = PriceChartViewModel(url: dataURL, dbService: dbService)
        vm.onError = { message in
            alertManager.showAlert(message: message)
        }
        viewModel = vm

        do {
            try dbService.initDatabase()
        } catch {
            alertManager.showAlert(message: error.localizedDescription)
            return
        }

        // Set the default interval based on data timespan
        let fileName = dataURL.lastPathComponent
        if let parsed = ParquetFileNameParser.parse(fileName),
           let minInterval = parsed.minimumInterval {
            await vm.setTimeInterval(minInterval, visibleCount: visibleCount)
        }

        await vm.loadInitialData(visibleCount: visibleCount)
        scrollPosition = vm.scrollPositionIndex
    }

    private func loadOverlayData() async {
        do {
            try dbService.initDatabase()

            // Load trades
            if FileManager.default.fileExists(atPath: tradesFilePath) {
                trades = try await dbService.fetchAllTrades(filePath: tradesURL)
            }

            // Load marks
            if FileManager.default.fileExists(atPath: marksFilePath) {
                marks = try await dbService.fetchMarkData(filePath: marksURL)
            }

            buildOverlays()
        } catch {
            alertManager.showAlert(message: "Failed to load overlay data: \(error.localizedDescription)")
        }
    }

    private func buildOverlays() {
        guard let vm = viewModel, !vm.sortedData.isEmpty else {
            tradeOverlays = []
            markOverlays = []
            return
        }

        // Build trade overlays by matching timestamps to price data indices
        tradeOverlays = trades.compactMap { trade in
            guard let executedAt = trade.executedAt else { return nil }

            // Find the closest price data index for this trade timestamp
            if let index = findClosestIndex(for: executedAt, in: vm.sortedData) {
                let isBuy = trade.orderType.lowercased().contains("buy")
                return TradeOverlay(
                    id: trade.orderId,
                    index: index,
                    price: trade.executedPrice,
                    isBuy: isBuy,
                    trade: trade
                )
            }
            return nil
        }

        // Build mark overlays by matching market_data_id to price data
        markOverlays = marks.compactMap { mark in
            // Try to find price data by ID
            if let index = vm.sortedData.firstIndex(where: { $0.id == mark.marketDataId }) {
                let priceData = vm.sortedData[index]
                return MarkOverlay(
                    id: mark.marketDataId,
                    index: index,
                    price: priceData.close,
                    mark: mark
                )
            }
            return nil
        }
    }

    /// Find the closest index in sorted price data for a given timestamp
    private func findClosestIndex(for date: Date, in data: [PriceData]) -> Int? {
        guard !data.isEmpty else { return nil }

        // Binary search for closest timestamp
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
                return low - 1
            }
        }

        return low
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
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        Group {
            if let idx = selectedIndex,
               let item = viewModel?.priceData(at: idx) {
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
        if let vm = viewModel {
            PriceChartView(
                indexedData: vm.indexedData,
                chartType: chartType,
                candlestickWidth: candlestickWidth,
                yAxisDomain: vm.yAxisDomain,
                visibleCount: visibleCount,
                scrollPosition: $scrollPosition,
                selectedIndex: $selectedIndex,
                tradeOverlays: tradeOverlays,
                markOverlays: markOverlays,
                onScrollChange: { newIndex in
                    vm.scrollPositionIndex = newIndex

                    loadDataTask?.cancel()
                    loadDataTask = Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        guard !Task.isCancelled else { return }
                        await vm.checkAndLoadMoreData(at: newIndex, visibleCount: visibleCount)
                    }
                }
            )
            .gesture(magnificationGesture)
        }
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
            // Overlay info
            HStack(spacing: 12) {
                if !tradeOverlays.isEmpty {
                    Label("\(tradeOverlays.count) trades", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !markOverlays.isEmpty {
                    Label("\(markOverlays.count) marks", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let vm = viewModel {
                Text("Showing \(vm.loadedData.count) of \(vm.totalCount) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Scroll to navigate, pinch to zoom")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 24)
    }

    // MARK: - Chart Controls

    private var chartControlsView: some View {
        HStack(spacing: 12) {
            // Interval selector
            HStack(spacing: 4) {
                Text("Interval:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Interval", selection: Binding(
                    get: { viewModel?.timeInterval ?? .oneSecond },
                    set: { newInterval in
                        guard let vm = viewModel else { return }
                        Task {
                            await vm.setTimeInterval(newInterval, visibleCount: visibleCount)
                        }
                    }
                )) {
                    ForEach(availableIntervals) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(viewModel?.isLoading ?? false)
            }

            // Loading indicator
            if let vm = viewModel, vm.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }

            Spacer()

            // Chart type picker
            Picker("", selection: $chartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
        .frame(height: 32)
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
