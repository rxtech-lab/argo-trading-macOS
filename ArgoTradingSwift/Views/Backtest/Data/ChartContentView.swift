//
//  ChartContentView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct ChartContentView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager

    @State private var viewModel: PriceChartViewModel?
    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var zoomScale: CGFloat = 1.0
    @State private var scrollPosition: Int = 0
    @State private var loadDataTask: Task<Void, Never>?
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Zoom configuration
    private let baseVisibleCount = 100
    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 5.0

    // MARK: - Computed Properties

    /// Available time intervals filtered based on the original data timespan
    private var availableIntervals: [ChartTimeInterval] {
        ChartTimeInterval.filtered(for: url)
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
                        description: Text("Load a dataset to view the chart")
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
        }
        .onChange(of: url) { _, newUrl in
            Task {
                await initializeViewModel(for: newUrl)
            }
        }
        .onChange(of: viewModel?.initialScrollPosition) { _, newValue in
            // Sync scroll position from view model (e.g., after loading more data)
            if let newValue, newValue != scrollPosition {
                scrollPosition = newValue
            }
        }
    }

    // MARK: - Initialization

    private func initializeViewModel(for fileUrl: URL? = nil) async {
        let targetUrl = fileUrl ?? url
        let vm = PriceChartViewModel(url: targetUrl, dbService: dbService)
        vm.onError = { message in
            alertManager.showAlert(message: message)
        }
        viewModel = vm

        // Initialize database before any operations
        do {
            try dbService.initDatabase()
        } catch {
            alertManager.showAlert(message: error.localizedDescription)
            return
        }

        // Set the default interval to the minimum valid interval based on data timespan
        let fileName = targetUrl.lastPathComponent
        if let parsed = ParquetFileNameParser.parse(fileName),
           let minInterval = parsed.minimumInterval
        {
            await vm.setTimeInterval(minInterval, visibleCount: visibleCount)
        }

        await vm.loadInitialData(visibleCount: visibleCount)
        // Sync initial scroll position from view model
        scrollPosition = vm.initialScrollPosition
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

    // MARK: - Legend (shows OHLCV on hover)

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
                initialScrollPosition: scrollPosition,
                totalDataCount: vm.totalCount,
                onScrollChange: { range in
                    if range.isNearStart(threshold: 50) {
                        loadDataTask?.cancel()
                        loadDataTask = Task {
                            print("Loading more data at beginning...")
                            await vm.loadMoreAtBeginning(at: range.globalFromIndex)
                        }
                    }

                    if range.isNearEnd(threshold: 50) {
                        loadDataTask?.cancel()
                        loadDataTask = Task {
                            try? await Task.sleep(for: .milliseconds(50))
                            guard !Task.isCancelled else { return }
                            await vm.loadMoreAtEnd()
                        }
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

    // MARK: - Chart Controls (interval selector + chart type picker)

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
                Task {
                    await vm.setTimeInterval(newInterval, visibleCount: visibleCount)
                }
            }
        )
    }
}

#Preview {
    ChartContentView(url: URL(fileURLWithPath: "/tmp/test.parquet"))
        .environment(DuckDBService())
        .environment(AlertManager())
}
