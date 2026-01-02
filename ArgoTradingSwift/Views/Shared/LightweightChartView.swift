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
    let initialScrollPosition: Int
    let totalDataCount: Int

    var tradeOverlays: [TradeOverlay] = []
    var markOverlays: [MarkOverlay] = []
    var showTrades: Bool = true
    var showMarks: Bool = true

    var onScrollChange: ((VisibleLogicalRange) async -> Void)?
    var onSelectionChange: ((Int?) -> Void)?

    // MARK: - State

    @Environment(LightweightChartService.self) private var chartService
    @State private var isChartReady = false
    @State private var lastDataHash: Int = 0
    @State private var lastMarkersHash: Int = 0
    @State private var scrollSubject = PassthroughSubject<JSVisibleRange, Never>()
    @State private var scrollCancellable: AnyCancellable?

    var body: some View {
        WebView(chartService.webpage)
            .task {
                // Setup callbacks before initialization
                setupCallbacks()

                do {
                    // This now waits for HTML to load first
                    try await chartService.initializeChart(chartType: chartType)

                    // Mark as ready - this enables data updates
                    isChartReady = true
                    logger.info("Chart initialized, isChartReady = true")

                    // Now safe to send initial data
                    await updateChartData()
                } catch {
                    logger.error("Failed to initialize chart: \(error.localizedDescription)")
                }
            }
            .onChange(of: data) { _, newData in
                logger.info("onChange(data) triggered - newData.count: \(newData.count)")
                Task { await updateChartData() }
            }
//        .onChange(of: chartType) { _, newType in
//            Task {
//                try? await chartService.switchChartType(newType)
//                await updateChartData()
//            }
//        }
//        .onChange(of: tradeOverlays) { _, _ in
//            Task { await updateMarkers() }
//        }
//        .onChange(of: markOverlays) { _, _ in
//            Task { await updateMarkers() }
//        }
//        .onChange(of: showTrades) { _, visible in
//            Task { try? await chartService.setMarkersVisible(visible, type: "trade") }
//        }
//        .onChange(of: showMarks) { _, visible in
//            Task { try? await chartService.setMarkersVisible(visible, type: "mark") }
//        }
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        // Setup scroll subscription with debouncing
        scrollCancellable = scrollSubject
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { range in
                Task {
                    await handleVisibleRangeChange(range)
                }
            }

        // Wire up service callbacks
        chartService.onVisibleRangeChange = { range in
            scrollSubject.send(range)
        }

        chartService.onCrosshairMove = { _ in
//            onSelectionChange?(data.globalIndex)
        }
    }

    @MainActor
    private func handleVisibleRangeChange(_ range: JSVisibleRange) async {
        // Convert JS range to VisibleLogicalRange
        let from = Int(range.from)
        let to = Int(range.to)

        let visibleRange = VisibleLogicalRange(
            globalFromIndex: from,
            localFromIndex: from,
            globalToIndex: to,
            localToIndex: to,
            totalCount: visibleCount
        )

        await onScrollChange?(visibleRange)
    }

    private func updateChartData() async {
        logger.info("updateChartData - isChartReady: \(isChartReady), data.count: \(data.count)")
        guard isChartReady, !data.isEmpty else {
            logger.warning("updateChartData SKIPPED - isChartReady: \(isChartReady), data.isEmpty: \(data.isEmpty)")
            return
        }

        // Check if data actually changed
        let newHash = data.hashValue
        guard newHash != lastDataHash else {
            logger.debug("updateChartData SKIPPED - data unchanged")
            return
        }
        lastDataHash = newHash

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

        // Only include visible markers
        let visibleTrades = showTrades ? tradeOverlays : []
        let visibleMarks = showMarks ? markOverlays : []

        // Check if markers actually changed
        let newHash = visibleTrades.hashValue ^ visibleMarks.hashValue
        guard newHash != lastMarkersHash else { return }
        lastMarkersHash = newHash

        do {
            try await chartService.setMarkers(trades: visibleTrades, marks: visibleMarks)
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
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
