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

    public let data: [PriceData]
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

    // Tooltip state
    @State private var tooltipData: JSMarkerHoverData?

    // MARK: - Initializers

    public init(
        data: [PriceData],
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
        self.data = data
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
            .onChange(of: data, handleDataChange)
            .onChange(of: chartType, handleChartTypeChange)
            .onChange(of: markers, handleMarkersChange)
            .onChange(of: showTrades, handleShowTradesChange)
            .onChange(of: scrollToTime, handleScrollToTimeChange)
            .onChange(of: indicatorSettings, handleIndicatorSettingsChange)
            .onChange(of: showVolume, handleShowVolumeChange)
            .onDisappear {
                Task {
                    await chartService.onClean()
                }
            }
    }

    private func handleDataChange(_: [PriceData], _: [PriceData]) {
        Task { await updateChartData() }
    }

    private func handleChartTypeChange(_: ChartType, _ newType: ChartType) {
        Task {
            try? await chartService.switchChartType(newType)
            await updateChartData()
        }
    }

    private func handleMarkersChange(_: [MarkerDataJS], _: [MarkerDataJS]) {
        Task { await updateMarkers() }
    }

    private func handleShowTradesChange(_: Bool, _ visible: Bool) {
        Task { try? await chartService.setMarkersVisible(visible, type: "trade") }
    }

    private func handleScrollToTimeChange(_: Date?, _ newTime: Date?) {
        guard let time = newTime, isChartReady else { return }
        Task {
            try? await chartService.scrollToTime(time)
        }
    }

    private func handleIndicatorSettingsChange(
        _: IndicatorSettings, _ newSettings: IndicatorSettings
    ) {
        guard isChartReady else { return }
        Task {
            try? await chartService.setIndicators(newSettings)
        }
    }

    private func handleShowVolumeChange(_: Bool, _ visible: Bool) {
        guard isChartReady else { return }
        Task {
            try? await chartService.setVolumeVisible(visible)
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
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    WebView(chartService.webpage)
                        .webViewContentBackground(.hidden)

                    // Native tooltip overlay
                    if let data = tooltipData {
                        ChartMarkerTooltip(data: data)
                            .position(tooltipPosition(for: data, in: geometry.size))
                            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    }
                }
            }
        }
    }

    /// Calculate tooltip position, adjusting for screen edges
    private func tooltipPosition(for data: JSMarkerHoverData, in size: CGSize) -> CGPoint {
        let tooltipWidth: CGFloat = 260
        let tooltipHeight: CGFloat = 200
        let padding: CGFloat = 15

        var x = data.screenX + padding
        var y = data.screenY - 10

        // Adjust if tooltip would go off right edge
        if x + tooltipWidth > size.width {
            x = data.screenX - tooltipWidth - padding
        }

        // Adjust if tooltip would go off bottom edge
        if y + tooltipHeight > size.height {
            y = size.height - tooltipHeight - 10
        }

        // Ensure tooltip doesn't go above top edge
        if y < 10 {
            y = 10
        }

        // Position is center of the view, so adjust for tooltip size
        return CGPoint(x: x + tooltipWidth / 2, y: y + tooltipHeight / 2)
    }

    private var hasNoData: Bool {
        data.isEmpty
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
        scrollCancellable =
            scrollSubject
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

        chartService.onCrosshairMove = { crosshairData in
            onSelectionChange?(crosshairData.globalIndex)
        }

        chartService.onMarkerHover = { hoverData in
            tooltipData = hoverData
            onMarkerHover?(hoverData)
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
        guard isChartReady, !data.isEmpty else { return }

        do {
            if chartType == .candlestick {
                let jsData = data.map { $0.toCandlestickJS() }
                try await chartService.setCandlestickData(jsData)
            } else {
                let jsData = data.map { $0.toLineJS() }
                try await chartService.setLineData(jsData)
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
