//
//  LiveChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import LightweightChart
import SwiftUI

/// Chart view for live trading with indicator controls, legend, and interval aggregation.
/// Combines historical Parquet data (loaded via DuckDB) with in-memory live data from TradingService.
struct LiveChartView: View {
    @Environment(TradingService.self) private var tradingService
    @Environment(DuckDBService.self) private var dbService

    // Identifier used to trigger data reload when the selected run changes
    var runURL: URL?

    // File paths for historical data (empty string = no file)
    var marketDataFilePath: String = ""
    var tradesFilePath: String = ""
    var marksFilePath: String = ""

    // Historical data loaded from Parquet
    @State private var historicalData: [PriceData] = []
    @State private var markers: [MarkerDataJS] = []
    @State private var isLoadingHistorical: Bool = false

    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var selectedInterval: ChartTimeInterval = .oneSecond

    // Indicator settings persisted to AppStorage (shared with backtest views)
    @AppStorage("indicatorSettings") private var indicatorSettingsData: Data?
    @State private var indicatorSettings: IndicatorSettings = .default

    // Mark level filter persisted to AppStorage
    @AppStorage("markLevelFilter") private var markLevelFilterData: Data?
    @State private var markLevelFilter: MarkLevelFilter = .default

    // Volume visibility
    @State private var showVolume: Bool = true

    /// Available intervals filtered to those >= the engine's base interval
    private var availableIntervals: [ChartTimeInterval] {
        ChartTimeInterval.filtered(minimumSeconds: tradingService.baseInterval.seconds)
    }

    /// Combined display data: historical + live
    private var displayData: [PriceData] {
        let combined = historicalData + tradingService.liveChartData
        if selectedInterval == tradingService.baseInterval {
            return combined
        }
        return LiveChartDataAggregator.aggregate(combined, intervalSeconds: selectedInterval.seconds)
    }

    /// Filtered markers based on mark level filter
    private var filteredMarkers: [MarkerDataJS] {
        markers.filter { marker in
            if marker.markerType == "trade" { return true }
            guard let level = marker.level else { return true }
            return markLevelFilter.shouldShow(level: level)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            legendView
            chartContent
            Divider()
            chartControlsView
        }
        .padding()
        .task(id: runURL) {
            // Reset state when switching runs
            historicalData = []
            markers = []
            selectedIndex = nil
            await loadHistoricalData()
        }
        .onChange(of: tradingService.isRunning) { oldValue, newValue in
            if oldValue && !newValue {
                // Trading stopped — reload parquet data (files are now finalized)
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    await loadHistoricalData()
                }
            }
        }
        .onAppear {
            indicatorSettings = IndicatorSettings.fromData(indicatorSettingsData)
            markLevelFilter = MarkLevelFilter.fromData(markLevelFilterData)
            selectedInterval = tradingService.baseInterval
        }
        .onChange(of: tradingService.baseInterval) { _, newInterval in
            // Reset to base when engine reports a new interval
            selectedInterval = newInterval
        }
    }

    // MARK: - Historical Data Loading

    private func loadHistoricalData() async {
        guard !marketDataFilePath.isEmpty else {
            historicalData = []
            markers = []
            return
        }

        let fileURL = URL(fileURLWithPath: marketDataFilePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            historicalData = []
            markers = []
            return
        }

        isLoadingHistorical = true
        defer { isLoadingHistorical = false }

        do {
            try dbService.initDatabase()

            // Load all historical price data
            let totalCount = try await dbService.getTotalCount(for: fileURL)
            let data = try await dbService.fetchAggregatedPriceDataRange(
                filePath: fileURL,
                interval: .oneSecond,
                startOffset: 0,
                count: totalCount
            )
            historicalData = data
        } catch {
            logger.error("Failed to load historical price data from '\(marketDataFilePath)' (exists: \(FileManager.default.fileExists(atPath: fileURL.path))): \(String(describing: error))")
            historicalData = []
            markers = []
            return
        }

        // Load trades and marks separately — failures here should not wipe out market data
        var loadedMarkers: [MarkerDataJS] = []

        if !tradesFilePath.isEmpty, let first = historicalData.first, let last = historicalData.last {
            let tradesURL = URL(fileURLWithPath: tradesFilePath)
            if FileManager.default.fileExists(atPath: tradesURL.path) {
                do {
                    let trades = try await dbService.fetchTrades(
                        filePath: tradesURL,
                        startTime: first.date,
                        endTime: last.date
                    )
                    loadedMarkers.append(contentsOf: trades.map { $0.toMarkerDataJS() })
                } catch {
                    logger.error("Failed to load trades from '\(tradesFilePath)': \(String(describing: error))")
                }
            }
        }

        if !marksFilePath.isEmpty, let first = historicalData.first, let last = historicalData.last {
            let marksURL = URL(fileURLWithPath: marksFilePath)
            if FileManager.default.fileExists(atPath: marksURL.path) {
                do {
                    let marks = try await dbService.fetchMarks(
                        filePath: marksURL,
                        startTime: first.date,
                        endTime: last.date
                    )
                    loadedMarkers.append(contentsOf: marks.map { $0.toMarkerDataJS() })
                } catch {
                    logger.error("Failed to load marks from '\(marksFilePath)': \(String(describing: error))")
                }
            }
        }

        markers = loadedMarkers
    }

    // MARK: - Header

    private var headerView: some View {
        ChartHeaderView(
            title: "Live Chart",
            showVolume: $showVolume,
            indicatorSettings: $indicatorSettings,
            markLevelFilter: $markLevelFilter,
            onIndicatorsChange: { newSettings in
                indicatorSettingsData = newSettings.toData()
            },
            onMarkLevelFilterChange: { newFilter in
                markLevelFilterData = newFilter.toData()
            }
        )
    }

    // MARK: - Legend

    private var legendView: some View {
        ChartLegendView(
            priceData: selectedIndex.flatMap { idx in
                let data = displayData
                guard idx >= 0, idx < data.count else { return nil }
                return data[idx]
            }
        )
    }

    // MARK: - Chart Content

    private var chartContent: some View {
        LightweightChartView(
            data: displayData,
            chartType: chartType,
            isLoading: isLoadingHistorical,
            totalDataCount: displayData.count,
            markers: filteredMarkers,
            showVolume: showVolume,
            indicatorSettings: indicatorSettings,
            onSelectionChange: { newIndex in
                selectedIndex = newIndex
            }
        )
    }

    // MARK: - Chart Controls

    private var chartControlsView: some View {
        ChartControlsView(
            availableIntervals: availableIntervals,
            selectedInterval: $selectedInterval,
            chartType: $chartType,
            isLoading: isLoadingHistorical
        )
    }
}
