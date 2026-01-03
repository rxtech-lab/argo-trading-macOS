//
//  LightweightChartView.swift
//  ArgoTradingSwift
//
//  SwiftUI wrapper for TradingView Lightweight Charts using WKWebView
//

import Combine
import SwiftUI
import WebKit

/// SwiftUI wrapper for TradingView Lightweight Charts
struct LightweightChartView: View {
    // MARK: - Properties (matching PriceChartView API)

    let data: [PriceData]
    let chartType: ChartType
    let candlestickWidth: CGFloat
    let visibleCount: Int
    let isLoading: Bool
    let totalDataCount: Int

    var tradeOverlays: [TradeOverlay] = []
    var markOverlays: [MarkOverlay] = []
    var showTrades: Bool = true
    var scrollToTime: Date?

    var onScrollChange: ((VisibleLogicalRange) async -> Void)?
    var onSelectionChange: ((Int?) -> Void)?

    // MARK: - State

    @Environment(LightweightChartService.self) private var chartService
    @State private var isChartReady = false
    @State private var scrollSubject = PassthroughSubject<JSVisibleRange, Never>()
    @State private var scrollCancellable: AnyCancellable?

    var body: some View {
        chartContent
            .task {
                await initializeChart()
            }
            .onChange(of: data) { _, newData in
                logger.info("onChange(data) triggered - newData.count: \(newData.count)")
                Task { await updateChartData() }
            }
            .onChange(of: chartType) { _, newType in
                Task {
                    try? await chartService.switchChartType(newType)
                    await updateChartData()
                }
            }
            .onChange(of: tradeOverlays) { _, _ in
                Task { await updateMarkers() }
            }
            .onChange(of: markOverlays) { _, _ in
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
        } else if data.isEmpty && !isLoading {
            ContentUnavailableView(
                "No Data",
                systemImage: "chart.xyaxis.line",
                description: Text("No price data available")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && data.isEmpty {
            ProgressView("Loading chart data...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WebView(chartService.webpage)
                .webViewContentBackground(.hidden)
        }
    }

    private func initializeChart() async {
        // Setup callbacks before initialization
        setupCallbacks()

        do {
            // This now waits for HTML to load first
            try await chartService.initializeChart(chartType: chartType)

            // Mark as ready - this enables data updates
            isChartReady = true
            logger.info("Chart initialized, isChartReady = true")

            // Now safe to send initial data
            // and clear all existing markers
            try await chartService.clearAllMarks()
            await updateChartData()

        } catch {
            logger.error("Failed to initialize chart: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        // Setup scroll subscription with debouncing
        scrollCancellable = scrollSubject
            .debounce(for: .milliseconds(40), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { range in
                Task {
                    await handleVisibleRangeChange(range)
                }
            }

        // Wire up service callbacks
        chartService.onVisibleRangeChange = { range in
            scrollSubject.send(range)
        }

        chartService.onCrosshairMove = { data in
            onSelectionChange?(data.globalIndex)
        }
    }

    @MainActor
    private func handleVisibleRangeChange(_ range: JSVisibleRange) async {
        // Convert JS range to VisibleLogicalRange
        let from = Int(range.from)
        let to = Int(range.to)

        let visibleRange = VisibleLogicalRange(
            localFromIndex: from,
            localToIndex: to,
        )
        logger.debug("Visible range changed: \(range.from) - \(range.to)")

        await onScrollChange?(visibleRange)
    }

    @MainActor
    private func updateChartData() async {
        guard isChartReady, !data.isEmpty else {
            logger.warning("updateChartData SKIPPED - isChartReady: \(isChartReady), data.isEmpty: \(data.isEmpty)")
            return
        }

        logger.info("SENDING \(data.count) items to chart, type: \(chartType)")
        do {
            if chartType == .candlestick {
                try await chartService.setCandlestickData(data)
            } else {
                try await chartService.setLineData(data)
            }
            logger.info("Chart data sent successfully")
        } catch {
            logger.error("Failed to update chart data: \(error.localizedDescription)")
        }
    }

    private func updateMarkers() async {
        guard isChartReady else { return }

        // Trades can be toggled, marks are always shown
        let visibleTrades = showTrades ? tradeOverlays : []
        do {
            try await chartService.setMarkers(trades: visibleTrades, marks: markOverlays)
        } catch {
            logger.error("Failed to update markers: \(error.localizedDescription)")
        }
    }
}

// MARK: - TradeOverlay Hashable

extension TradeOverlay: Hashable {
    static func == (lhs: TradeOverlay, rhs: TradeOverlay) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(timestamp)
    }
}

// MARK: - MarkOverlay Hashable

extension MarkOverlay: Hashable {
    static func == (lhs: MarkOverlay, rhs: MarkOverlay) -> Bool {
        lhs.id == rhs.id && lhs.alignedTime == rhs.alignedTime
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(alignedTime)
    }
}
