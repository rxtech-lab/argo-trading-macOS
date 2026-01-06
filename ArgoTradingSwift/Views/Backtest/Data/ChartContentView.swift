//
//  ChartContentView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import LightweightChart
import SwiftUI

struct ChartContentView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(BacktestResultService.self) private var backtestResultService

    @State private var viewModel: PriceChartViewModel?
    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var scrollPosition: Int = 0
    @GestureState private var magnifyBy: CGFloat = 1.0
    @State private var scrollToTime: Date?

    // Indicator settings persisted to AppStorage
    @AppStorage("indicatorSettings") private var indicatorSettingsData: Data?
    @State private var indicatorSettings: IndicatorSettings = .default

    // Volume visibility
    @State private var showVolume: Bool = true

    // MARK: - Computed Properties

    /// Available time intervals filtered based on the original data timespan
    private var availableIntervals: [ChartTimeInterval] {
        ChartTimeInterval.filtered(for: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            legendView

            if viewModel != nil {
                chartContent
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
        .onAppear {
            // Load indicator settings from AppStorage
            indicatorSettings = IndicatorSettings.fromData(indicatorSettingsData)
        }
        .onChange(of: url) { _, newUrl in
            Task {
                await initializeViewModel(for: newUrl)
            }
        }
        .onChange(of: backtestResultService.chartScrollRequest) { _, newRequest in
            guard let request = newRequest,
                  request.dataFilePath == url.path else { return }
            Task {
                await viewModel?.scrollToTimestamp(request.timestamp)
                scrollToTime = request.timestamp
                backtestResultService.clearScrollRequest()
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
            await vm.setTimeInterval(minInterval)
        }

        await vm.loadInitialData()
    }

    // MARK: - Header

    private var headerView: some View {
        ChartHeaderView(
            title: "Price Chart",
            showVolume: $showVolume,
            indicatorSettings: $indicatorSettings,
            onIndicatorsChange: { newSettings in
                indicatorSettingsData = newSettings.toData()
            }
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
                isLoading: vm.isLoading,
                totalDataCount: vm.totalCount,
                showVolume: showVolume,
                scrollToTime: scrollToTime,
                indicatorSettings: indicatorSettings,
                onScrollChange: { range in
                    await vm.handleScrollChange(range)
                },
                onSelectionChange: { newIndex in
                    selectedIndex = newIndex
                }
            )
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
                    await vm.setTimeInterval(newInterval)
                }
            }
        )
    }
}

#Preview {
    ChartContentView(url: URL(fileURLWithPath: "/tmp/test.parquet"))
        .environment(DuckDBService())
        .environment(AlertManager())
        .environment(BacktestResultService())
}
