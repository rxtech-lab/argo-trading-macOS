//
//  LightweightChartService.swift
//  ArgoTradingSwift
//
//  Service for managing TradingView Lightweight Charts via WKWebView
//  This is a thin wrapper around the LightweightChart package that provides
//  conversion from app-specific types (PriceData, Trade, Mark) to package types.
//

import Foundation
import LightweightChart
import WebKit

// MARK: - App Logger

/// Logger that bridges to the app's logger
struct AppChartLogger: ChartLogger {
    func debug(_ message: String) {
        logger.debug("\(message)")
    }

    func info(_ message: String) {
        logger.info("\(message)")
    }

    func warning(_ message: String) {
        logger.warning("\(message)")
    }

    func error(_ message: String) {
        logger.error("\(message)")
    }
}

// MARK: - Type Aliases for Package Types (re-exported for compatibility)

// Re-export package types so existing code continues to work
public typealias ChartMessageType = LightweightChart.ChartMessageType
public typealias JSVisibleRange = LightweightChart.JSVisibleRange
public typealias JSCrosshairData = LightweightChart.JSCrosshairData
public typealias JSOHLCV = LightweightChart.JSOHLCV
public typealias JSMarkerHoverData = LightweightChart.JSMarkerHoverData
public typealias JSMarkerInfo = LightweightChart.JSMarkerInfo
public typealias CandlestickDataJS = LightweightChart.CandlestickDataJS
public typealias LineDataJS = LightweightChart.LineDataJS
public typealias MarkerDataJS = LightweightChart.MarkerDataJS
public typealias LightweightChartError = LightweightChart.LightweightChartError
public typealias ChartSchemeHandler = LightweightChart.ChartSchemeHandler
public typealias ChartMessageHandler = LightweightChart.ChartMessageHandler

// MARK: - PriceData Extensions

extension PriceData {
    /// Convert PriceData to CandlestickDataJS for the chart
    func toCandlestickDataJS() -> CandlestickDataJS {
        CandlestickDataJS(
            time: date.timeIntervalSince1970,
            open: open,
            high: high,
            low: low,
            close: close,
            globalIndex: globalIndex,
            volume: volume
        )
    }

    /// Convert PriceData to LineDataJS for the chart
    func toLineDataJS() -> LineDataJS {
        LineDataJS(
            time: date.timeIntervalSince1970,
            value: close,
            globalIndex: globalIndex,
            volume: volume
        )
    }
}

// MARK: - TradingView data scheme (for app's Bundle.main resources)

struct DataViewDataSchemeHandler: URLSchemeHandler {
    func reply(
        for request: URLRequest
    ) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream { continuation in
            guard let url = request.url else {
                continuation.finish(throwing: URLError(.badURL))
                return
            }

            // Parse filename from host (e.g., "chart.html" from "trading://chart.html")
            let filename = url.host ?? ""
            let fileExtension = (filename as NSString).pathExtension
            let resourceName = (filename as NSString).deletingPathExtension
            logger.debug("[DataSchemeHandler] Loading resource: \(resourceName).\(fileExtension)")

            // Load from tradingview subdirectory in bundle
            guard
                let bundleURL = Bundle.main.url(
                    forResource: resourceName,
                    withExtension: fileExtension.isEmpty ? nil : fileExtension,
                    subdirectory: "tradingview"
                ),
                let pageData = try? Data(contentsOf: bundleURL)
            else {
                continuation.finish(throwing: URLError(.fileDoesNotExist))
                return
            }

            // Determine MIME type based on file extension
            let mimeType: String
            switch fileExtension.lowercased() {
            case "html": mimeType = "text/html"
            case "js": mimeType = "application/javascript"
            case "css": mimeType = "text/css"
            case "json": mimeType = "application/json"
            case "png": mimeType = "image/png"
            case "jpg", "jpeg": mimeType = "image/jpeg"
            case "svg": mimeType = "image/svg+xml"
            default: mimeType = "application/octet-stream"
            }

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: pageData.count,
                textEncodingName: "utf-8"
            )
            continuation.yield(.response(response))
            continuation.yield(.data(pageData))
            continuation.finish()
        }
    }
}

// MARK: - LightweightChartService (App wrapper)

/// App-specific wrapper around the package's LightweightChartService
/// Provides methods that accept app types (PriceData, Trade, Mark) and converts them
@Observable
@MainActor
final class LightweightChartService {
    // Use the package's underlying service
    private let packageService: LightweightChart.LightweightChartService

    // Expose the webpage for the view
    var webpage: WebPage {
        packageService.webpage
    }

    // Public callbacks for view layer
    var onVisibleRangeChange: ((JSVisibleRange) -> Void)? {
        get { packageService.onVisibleRangeChange }
        set { packageService.onVisibleRangeChange = newValue }
    }

    var onCrosshairMove: ((JSCrosshairData) -> Void)? {
        get { packageService.onCrosshairMove }
        set { packageService.onCrosshairMove = newValue }
    }

    var onMarkerHover: ((JSMarkerHoverData?) -> Void)? {
        get { packageService.onMarkerHover }
        set { packageService.onMarkerHover = newValue }
    }

    // MARK: - Initialization

    init() {
        self.packageService = LightweightChart.LightweightChartService(logger: AppChartLogger())
    }

    // MARK: - Forwarded Methods

    func clearAllMarks() async throws {
        try await packageService.clearAllMarks()
    }

    func onClean() async {
        await packageService.onClean()
    }

    func waitForPageLoaded() async {
        await packageService.waitForPageLoaded()
    }

    func initializeChart(chartType: ChartType) async throws {
        let packageChartType = chartType == .candlestick
            ? LightweightChart.ChartType.candlestick
            : LightweightChart.ChartType.line
        try await packageService.initializeChart(chartType: packageChartType)
    }

    /// Set candlestick data from PriceData array
    func setCandlestickData(_ data: [PriceData]) async throws {
        let jsData = data.map { $0.toCandlestickDataJS() }
        try await packageService.setCandlestickData(jsData)
    }

    /// Set line data from PriceData array
    func setLineData(_ data: [PriceData]) async throws {
        let jsData = data.map { $0.toLineDataJS() }
        try await packageService.setLineData(jsData)
    }

    /// Update a single candlestick data point
    func updateCandlestickData(_ data: PriceData) async throws {
        try await packageService.updateCandlestickData(data.toCandlestickDataJS())
    }

    /// Update a single line data point
    func updateLineData(_ data: PriceData) async throws {
        try await packageService.updateLineData(data.toLineDataJS())
    }

    /// Set markers (trades and marks) on the chart
    func setMarkers(trades: [TradeOverlay], marks: [MarkOverlay]) async throws {
        var markers: [MarkerDataJS] = []

        // Convert trade overlays to markers
        for trade in trades {
            var marker = MarkerDataJS(
                time: trade.timestamp.timeIntervalSince1970,
                position: "aboveBar",
                color: trade.isBuy ? "#26a69a" : "#ef5350",
                shape: "arrowDown",
                text: trade.isBuy ? "B" : "S",
                id: trade.id,
                markerType: "trade"
            )

            // Add trade details for tooltip
            marker.isBuy = trade.isBuy
            marker.symbol = trade.trade.symbol
            marker.positionType = trade.trade.positionType
            marker.executedQty = trade.trade.executedQty
            marker.executedPrice = trade.trade.executedPrice
            marker.pnl = trade.trade.pnl
            marker.reason = trade.trade.reason

            markers.append(marker)
        }

        // Convert mark overlays to markers
        for markOverlay in marks {
            let mark = markOverlay.mark
            var marker = MarkerDataJS(
                time: markOverlay.alignedTime.timeIntervalSince1970,
                position: "belowBar",
                color: mark.color.toHexString(),
                shape: mark.shape.toJSShape(),
                text: String(mark.title.prefix(1)),
                id: markOverlay.id,
                markerType: "mark"
            )

            // Add mark details for tooltip
            marker.title = mark.title
            marker.category = mark.category
            marker.message = mark.message
            marker.signalType = mark.signal.type.rawValue
            marker.signalReason = mark.signal.reason

            markers.append(marker)
        }

        try await packageService.setMarkers(markers)
    }

    func setMarkersVisible(_ visible: Bool, type: String) async throws {
        try await packageService.setMarkersVisible(visible, type: type)
    }

    func scrollToTime(_ timestamp: Date) async throws {
        try await packageService.scrollToTime(timestamp)
    }

    func setVisibleRange(from: Int, to: Int) async throws {
        try await packageService.setVisibleRange(from: from, to: to)
    }

    func resize(width: CGFloat, height: CGFloat) async throws {
        try await packageService.resize(width: width, height: height)
    }

    func fitContent() async throws {
        try await packageService.fitContent()
    }

    func scrollToRealtime() async throws {
        try await packageService.scrollToRealtime()
    }

    func setVolumeVisible(_ visible: Bool) async throws {
        try await packageService.setVolumeVisible(visible)
    }

    func switchChartType(_ chartType: ChartType) async throws {
        let packageChartType = chartType == .candlestick
            ? LightweightChart.ChartType.candlestick
            : LightweightChart.ChartType.line
        try await packageService.switchChartType(packageChartType)
    }

    // MARK: - Indicators

    func setIndicators(_ settings: IndicatorSettings) async throws {
        // Convert app's IndicatorSettings to package's IndicatorSettings
        let packageIndicators = settings.indicators.map { config in
            var packageConfig = LightweightChart.IndicatorConfig(
                type: LightweightChart.IndicatorType(rawValue: config.type.rawValue) ?? .sma,
                isEnabled: config.isEnabled
            )
            packageConfig.parameters = config.parameters
            packageConfig.color = config.color
            return packageConfig
        }
        let packageSettings = LightweightChart.IndicatorSettings(indicators: packageIndicators)
        try await packageService.setIndicators(packageSettings)
    }

    func clearIndicators() async throws {
        try await packageService.clearIndicators()
    }
}
