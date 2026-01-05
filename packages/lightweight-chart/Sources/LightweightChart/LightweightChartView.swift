//
//  LightweightChartView.swift
//  LightweightChart
//
//  SwiftUI wrapper for TradingView Lightweight Charts using WKWebView
//

import Combine
import SwiftUI
import WebKit

/// SwiftUI wrapper for TradingView Lightweight Charts
public struct LightweightChartView: View {
    // MARK: - Properties

    public let candlestickData: [CandlestickDataJS]
    public let lineData: [LineDataJS]
    public let chartType: ChartType
    public let isLoading: Bool
    public let totalDataCount: Int

    public var markers: [MarkerDataJS] = []
    public var showTrades: Bool = true
    public var showVolume: Bool = true
    public var scrollToTime: Date?
    public var indicatorSettings: IndicatorSettings = .default

    public var onScrollChange: ((VisibleLogicalRange) async -> Void)?
    public var onSelectionChange: ((Int?) -> Void)?
    public var onMarkerHover: ((JSMarkerHoverData?) -> Void)?

    // MARK: - State

    @Environment(LightweightChartService.self) private var chartService
    @State private var isChartReady = false
    @State private var scrollSubject = PassthroughSubject<JSVisibleRange, Never>()
    @State private var scrollCancellable: AnyCancellable?

    // MARK: - Initializers

    public init(
        candlestickData: [CandlestickDataJS] = [],
        lineData: [LineDataJS] = [],
        chartType: ChartType,
        isLoading: Bool,
        totalDataCount: Int,
        markers: [MarkerDataJS] = [],
        showTrades: Bool = true,
        showVolume: Bool = true,
        scrollToTime: Date? = nil,
        indicatorSettings: IndicatorSettings = .default,
        onScrollChange: ((VisibleLogicalRange) async -> Void)? = nil,
        onSelectionChange: ((Int?) -> Void)? = nil,
        onMarkerHover: ((JSMarkerHoverData?) -> Void)? = nil
    ) {
        self.candlestickData = candlestickData
        self.lineData = lineData
        self.chartType = chartType
        self.isLoading = isLoading
        self.totalDataCount = totalDataCount
        self.markers = markers
        self.showTrades = showTrades
        self.showVolume = showVolume
        self.scrollToTime = scrollToTime
        self.indicatorSettings = indicatorSettings
        self.onScrollChange = onScrollChange
        self.onSelectionChange = onSelectionChange
        self.onMarkerHover = onMarkerHover
    }

    public var body: some View {
        chartContent
            .task {
                await initializeChart()
            }
            .onChange(of: candlestickData) { _, _ in
                Task { await updateChartData() }
            }
            .onChange(of: lineData) { _, _ in
                Task { await updateChartData() }
            }
            .onChange(of: chartType) { _, newType in
                Task {
                    try? await chartService.switchChartType(newType)
                    await updateChartData()
                }
            }
            .onChange(of: markers) { _, _ in
                Task { await updateMarkers() }
            }
            .onChange(of: showTrades) { _, visible in
                Task { try? await chartService.setMarkersVisible(visible, type: "trade") }
            }
            .onChange(of: scrollToTime) { _, newTime in
                guard let time = newTime, isChartReady else { return }
                Task {
                    try? await chartService.scrollToTime(time)
                }
            }
            .onChange(of: indicatorSettings) { _, newSettings in
                guard isChartReady else { return }
                Task {
                    try? await chartService.setIndicators(newSettings)
                }
            }
            .onChange(of: showVolume) { _, visible in
                guard isChartReady else { return }
                Task {
                    try? await chartService.setVolumeVisible(visible)
                }
            }
            .onDisappear {
                Task {
                    await chartService.onClean()
                }
            }
    }

    @ViewBuilder
    private var chartContent: some View {
        if !isChartReady {
            ProgressView("Initializing...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if hasNoData && !isLoading {
            ContentUnavailableView(
                "No Data",
                systemImage: "chart.xyaxis.line",
                description: Text("No price data available")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && hasNoData {
            ProgressView("Loading chart data...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WebView(chartService.webpage)
                .webViewContentBackground(.hidden)
        }
    }

    private var hasNoData: Bool {
        candlestickData.isEmpty && lineData.isEmpty
    }

    private func initializeChart() async {
        // Setup callbacks before initialization
        setupCallbacks()

        do {
            try await chartService.initializeChart(chartType: chartType)

            isChartReady = true

            try await chartService.clearAllMarks()
            await updateChartData()

            if !indicatorSettings.enabledIndicators.isEmpty {
                try await chartService.setIndicators(indicatorSettings)
            }

        } catch {
            // Error handling - chart failed to initialize
        }
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        scrollCancellable = scrollSubject
            .debounce(for: .milliseconds(40), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { range in
                Task {
                    await handleVisibleRangeChange(range)
                }
            }

        chartService.onVisibleRangeChange = { range in
            scrollSubject.send(range)
        }

        chartService.onCrosshairMove = { data in
            onSelectionChange?(data.globalIndex)
        }

        chartService.onMarkerHover = { data in
            onMarkerHover?(data)
        }
    }

    @MainActor
    private func handleVisibleRangeChange(_ range: JSVisibleRange) async {
        let from = Int(range.from)
        let to = Int(range.to)

        let visibleRange = VisibleLogicalRange(
            localFromIndex: from,
            localToIndex: to
        )

        await onScrollChange?(visibleRange)
    }

    @MainActor
    private func updateChartData() async {
        guard isChartReady else { return }

        do {
            if chartType == .candlestick {
                guard !candlestickData.isEmpty else { return }
                try await chartService.setCandlestickData(candlestickData)
            } else {
                guard !lineData.isEmpty else { return }
                try await chartService.setLineData(lineData)
            }
        } catch {
            // Error handling
        }
    }

    private func updateMarkers() async {
        guard isChartReady else { return }

        let visibleMarkers = showTrades ? markers : markers.filter { $0.markerType != "trade" }
        do {
            try await chartService.setMarkers(visibleMarkers)
        } catch {
            // Error handling
        }
    }
}
