//
//  BacktestChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Chart view for backtest results with trade and mark overlays
struct BacktestChartView: View {
    let dataFilePath: String
    let tradesFilePath: String
    let marksFilePath: String

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(BacktestResultService.self) private var backtestResultService

    @State private var viewModel: PriceChartViewModel?
    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var zoomScale: CGFloat = 1.0
    @State private var scrollPosition: Int = 0
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Overlay data
    @State private var trades: [Trade] = []
    @State private var marks: [Mark] = []
    @State private var tradeOverlays: [TradeOverlay] = []
    @State private var markOverlays: [MarkOverlay] = []
    @State private var loadedOverlayRange: ClosedRange<Date>?
    @State private var isLoadingOverlays: Bool = false

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
            await loadVisibleOverlays()
        }
        .onChange(of: viewModel?.scrollPositionIndex) { _, newValue in
            if let newValue, newValue != scrollPosition {
                scrollPosition = newValue
            }
        }
        .onChange(of: dataFilePath) { _, _ in
            // Reset all state and reload when data file changes
            viewModel = nil
            trades = []
            marks = []
            tradeOverlays = []
            markOverlays = []
            loadedOverlayRange = nil
            scrollPosition = 0
            print("Data file changed, reloading chart and overlays")
            Task {
                await initializeViewModel()
                await loadVisibleOverlays()
            }
        }
        .onChange(of: backtestResultService.chartScrollRequest) { _, newRequest in
            guard let request = newRequest,
                  request.dataFilePath == dataFilePath else { return }

            Task {
                await viewModel?.scrollToTimestamp(request.timestamp, visibleCount: visibleCount)
                backtestResultService.clearScrollRequest()
            }
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
           let minInterval = parsed.minimumInterval
        {
            await vm.setTimeInterval(minInterval, visibleCount: visibleCount)
        }

        await vm.loadInitialData(visibleCount: visibleCount)
        scrollPosition = vm.scrollPositionIndex
    }

    /// Get the visible time range with buffer for overlay loading
    private func getVisibleTimeRange() -> ClosedRange<Date>? {
        guard let vm = viewModel, !vm.sortedData.isEmpty else { return nil }
        let buffer = 50 // Load extra on each side for smooth scrolling
        let startIdx = max(0, scrollPosition - buffer)
        let endIdx = min(vm.sortedData.count - 1, scrollPosition + visibleCount + buffer)
        return vm.sortedData[startIdx].date...vm.sortedData[endIdx].date
    }

    /// Load overlays for the visible time range
    private func loadVisibleOverlays() async {
        guard let range = getVisibleTimeRange() else { return }

        // Skip if range is fully covered by already-loaded range
        if let loaded = loadedOverlayRange,
           loaded.lowerBound <= range.lowerBound,
           loaded.upperBound >= range.upperBound
        {
            return
        }

        // Skip if already loading
        guard !isLoadingOverlays else { return }
        isLoadingOverlays = true
        defer { isLoadingOverlays = false }

        do {
            try dbService.initDatabase()

            // Load trades within time range
            if FileManager.default.fileExists(atPath: tradesFilePath) {
                trades = try await dbService.fetchTrades(
                    filePath: tradesURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }

            // Load marks within time range
            if FileManager.default.fileExists(atPath: marksFilePath) {
                marks = try await dbService.fetchMarks(
                    filePath: marksURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }

            buildOverlays()
            loadedOverlayRange = range
        } catch {
            alertManager.showAlert(message: "Failed to load overlay data: \(error.localizedDescription)")
        }
    }

    private func buildOverlays() {
        // Build trade overlays with timestamps (indices computed lazily in PriceChartView)
        tradeOverlays = trades.compactMap { trade in
            let isBuy = trade.side == .buy
            return TradeOverlay(
                id: trade.orderId,
                timestamp: trade.timestamp,
                price: trade.executedPrice,
                isBuy: isBuy,
                trade: trade
            )
        }

        // Build mark overlays with marketDataId (indices computed lazily in PriceChartView)
        markOverlays = marks.map { mark in
            MarkOverlay(
                id: mark.marketDataId,
                marketDataId: mark.marketDataId,
                price: 0, // Price will be looked up in PriceChartView
                mark: mark
            )
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ChartHeaderView(
            title: "Price Chart",
            zoomScale: $zoomScale,
            minZoom: minZoom,
            maxZoom: maxZoom
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        ChartLegendView(
            priceData: selectedIndex.flatMap { viewModel?.priceData(at: $0) }
        )
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
                isLoading: vm.isLoading,
                scrollPosition: $scrollPosition,
                tradeOverlays: tradeOverlays,
                markOverlays: markOverlays,
                onScrollChange: { range in
                    vm.scrollPositionIndex = range.from
                    if range.isNearStart(threshold: 50) {
                        print("Load more at beginning triggered, \(vm.isLoading)")
                        Task {
                            await vm.loadMoreAtBeginning()
                        }
                    }

                    if range.isNearEnd(threshold: 50) {
                        Task {
                            await vm.loadMoreAtEnd()
                        }
                    }

                    // Load overlays for the new visible range
                    Task {
                        await loadVisibleOverlays()
                    }
                },
                onSelectionChange: { newIndex in
                    selectedIndex = newIndex
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
        ChartControlsView(
            availableIntervals: availableIntervals,
            selectedInterval: Binding(
                get: { viewModel?.timeInterval ?? .oneSecond },
                set: { _ in }
            ),
            chartType: $chartType,
            isLoading: viewModel?.isLoading ?? false,
            onIntervalChange: { newInterval in
                guard let vm = viewModel else { return }
                // Reset overlay range when interval changes
                loadedOverlayRange = nil
                Task {
                    await vm.setTimeInterval(newInterval, visibleCount: visibleCount)
                    await loadVisibleOverlays()
                }
            }
        )
    }
}
