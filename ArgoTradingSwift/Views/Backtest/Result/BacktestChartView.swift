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
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Overlay visibility toggle (UI state only)
    @State private var showTrades: Bool = true

    // Scroll to timestamp request (passed to LightweightChartView)
    @State private var scrollToTime: Date?

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

    private func loadPriceData() async {
        // Reset view model when data file changes
        viewModel = nil

        // Initialize and load data
        logger.info("Loading backtest chart for data file: \(dataFilePath)")
        await initializeViewModel()
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
        .task(id: dataFilePath) {
            await loadPriceData()
        }
        .onChange(of: backtestResultService.chartScrollRequest) { _, newRequest in
            guard let request = newRequest,
                  request.dataFilePath == dataFilePath else { return }

            Task {
                await viewModel?.scrollToTimestamp(request.timestamp, visibleCount: visibleCount)
                // Reset loaded range to force overlay reload for the new visible area
                viewModel?.resetOverlayRange()
                await viewModel?.loadVisibleOverlays()

                // Trigger chart scroll to the timestamp
                scrollToTime = request.timestamp

                backtestResultService.clearScrollRequest()
            }
        }
        .gesture(magnificationGesture)
    }

    // MARK: - Initialization

    private func initializeViewModel() async {
        let vm = PriceChartViewModel(
            url: dataURL,
            dbService: dbService,
            tradesURL: tradesURL,
            marksURL: marksURL
        )
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
        await vm.loadVisibleOverlays()
    }

    // MARK: - Header

    private var headerView: some View {
        ChartHeaderView(
            title: "Price Chart",
            zoomScale: $zoomScale,
            minZoom: minZoom,
            maxZoom: maxZoom,
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
            LightweightChartView(
                data: vm.loadedData,
                chartType: chartType,
                candlestickWidth: candlestickWidth,
                visibleCount: visibleCount,
                isLoading: vm.isLoading,
                initialScrollPosition: vm.initialScrollPosition,
                totalDataCount: vm.totalCount,
                tradeOverlays: vm.tradeOverlays,
                markOverlays: vm.markOverlays,
                showTrades: showTrades,
                scrollToTime: scrollToTime,
                onScrollChange: { range in
                    await vm.handleScrollChange(range)
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
                if let vm = viewModel, !vm.tradeOverlays.isEmpty {
                    Label("\(vm.tradeOverlays.count) trades", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let vm = viewModel, !vm.markOverlays.isEmpty {
                    Label("\(vm.markOverlays.count) marks", systemImage: "mappin")
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
                vm.resetOverlayRange()
                Task {
                    await vm.setTimeInterval(newInterval, visibleCount: visibleCount)
                    await vm.loadVisibleOverlays()
                }
            }
        )
    }
}
