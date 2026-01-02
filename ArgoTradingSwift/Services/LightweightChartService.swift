//
//  LightweightChartService.swift
//  ArgoTradingSwift
//
//  Service for managing TradingView Lightweight Charts via WKWebView
//

import Foundation
import WebKit

// MARK: - Message Types

/// Message types sent from JavaScript to Swift
enum ChartMessageType: String, CaseIterable {
    case ready
    case visibleRangeChange
    case crosshairMove
    case consoleLog
}

// MARK: - JS Data Structures

/// Visible range from JavaScript
struct JSVisibleRange: Codable {
    let from: Double
    let to: Double
}

/// Crosshair data from JavaScript
struct JSCrosshairData {
    let time: Double?
    let price: Double?
    let globalIndex: Int?
    let ohlcv: JSOHLCV?
}

/// OHLCV data from JavaScript
struct JSOHLCV {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

/// Candlestick data for JavaScript
struct CandlestickDataJS: Codable {
    let time: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let globalIndex: Int
    let volume: Double

    init(from priceData: PriceData) {
        self.time = priceData.date.timeIntervalSince1970
        self.open = priceData.open
        self.high = priceData.high
        self.low = priceData.low
        self.close = priceData.close
        self.globalIndex = priceData.globalIndex
        self.volume = priceData.volume
    }
}

/// Line data for JavaScript
struct LineDataJS: Codable {
    let time: Double
    let value: Double
    let globalIndex: Int
    let volume: Double

    init(from priceData: PriceData) {
        self.time = priceData.date.timeIntervalSince1970
        self.value = priceData.close
        self.globalIndex = priceData.globalIndex
        self.volume = priceData.volume
    }
}

/// Marker data for JavaScript
struct MarkerDataJS: Codable {
    let time: Double
    let position: String
    let color: String
    let shape: String
    let text: String
    let id: String
    let markerType: String

    // Trade-specific fields
    var isBuy: Bool?
    var symbol: String?
    var positionType: String?
    var executedQty: Double?
    var executedPrice: Double?
    var pnl: Double?
    var reason: String?

    // MARK: - specific fields

    var title: String?
    var category: String?
    var message: String?
    var signalType: String?
    var signalReason: String?
}

// MARK: - Errors

enum LightweightChartError: Error, LocalizedError {
    case webViewNotConfigured
    case javascriptError(String)
    case resourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .webViewNotConfigured:
            return "WebView is not configured"
        case .javascriptError(let message):
            return "JavaScript error: \(message)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        }
    }
}

// MARK: - TradingView data scheme

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

// MARK: - LightweightChartService

@Observable
final class LightweightChartService {
    var webpage: WebPage

    // MARK: - JavaScript API

    @MainActor
    init() {
        let scheme = URLScheme("trading")!
        let handler = DataViewDataSchemeHandler()

        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[scheme] = handler

        self.webpage = WebPage(configuration: configuration)
        webpage.load(URL(string: "trading://chart.html")!)
    }

    /// Initialize the chart with a specific type
    func initializeChart(chartType: ChartType) async throws {
        let chartTypeJS = chartType == .candlestick ? "Candlestick" : "Line"
        try await callJavaScript("initializeChart('\(chartTypeJS)')")
    }

    /// Set candlestick data
    func setCandlestickData(_ data: [PriceData]) async throws {
        let jsData = data.map { CandlestickDataJS(from: $0) }
        let jsonData = try JSONEncoder().encode(jsData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("setCandlestickData(\(jsonString))")
    }

    /// Set line data
    func setLineData(_ data: [PriceData]) async throws {
        let jsData = data.map { LineDataJS(from: $0) }
        let jsonData = try JSONEncoder().encode(jsData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("setLineData(\(jsonString))")
    }

    /// Update a single candlestick data point
    func updateCandlestickData(_ data: PriceData) async throws {
        let jsData = CandlestickDataJS(from: data)
        let jsonData = try JSONEncoder().encode(jsData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("updateCandlestickData(\(jsonString))")
    }

    /// Update a single line data point
    func updateLineData(_ data: PriceData) async throws {
        let jsData = LineDataJS(from: data)
        let jsonData = try JSONEncoder().encode(jsData)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("updateLineData(\(jsonString))")
    }

    /// Set markers (trades and marks) on the chart
    func setMarkers(trades: [TradeOverlay], marks: [MarkOverlay]) async throws {
        var markers: [MarkerDataJS] = []

        // Convert trade overlays to markers
        for trade in trades {
            var marker = MarkerDataJS(
                time: trade.timestamp.timeIntervalSince1970,
                position: trade.isBuy ? "belowBar" : "aboveBar",
                color: trade.isBuy ? "#26a69a" : "#ef5350",
                shape: trade.isBuy ? "arrowUp" : "arrowDown",
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
                time: mark.signal.time.timeIntervalSince1970,
                position: "aboveBar",
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

        let jsonData = try JSONEncoder().encode(markers)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode markers")
        }
        try await callJavaScript("setMarkers(\(jsonString))")
    }

    /// Toggle visibility of markers by type
    func setMarkersVisible(_ visible: Bool, type: String) async throws {
        try await callJavaScript("setMarkersVisible(\(visible), '\(type)')")
    }

    /// Scroll to a specific timestamp
    func scrollToTime(_ timestamp: Date) async throws {
        let time = timestamp.timeIntervalSince1970
        try await callJavaScript("scrollToTime(\(time))")
    }

    /// Set the visible logical range
    func setVisibleRange(from: Int, to: Int) async throws {
        try await callJavaScript("setVisibleRange(\(from), \(to))")
    }

    /// Resize the chart
    func resize(width: CGFloat, height: CGFloat) async throws {
        try await callJavaScript("resizeChart(\(width), \(height))")
    }

    /// Fit all content in view
    func fitContent() async throws {
        try await callJavaScript("fitContent()")
    }

    /// Scroll to the latest (realtime) data
    func scrollToRealtime() async throws {
        try await callJavaScript("scrollToRealtime()")
    }

    /// Switch chart type
    func switchChartType(_ chartType: ChartType) async throws {
        let chartTypeJS = chartType == .candlestick ? "Candlestick" : "Line"
        try await callJavaScript("switchChartType('\(chartTypeJS)')")
    }

    // MARK: - Private Helpers

    @MainActor
    @discardableResult
    private func callJavaScript(_ js: String) async throws -> Any? {
        do {
            w
            return try await webpage.callJavaScript(js)
        } catch let error as NSError {
            // Log detailed error info for debugging
            logger.error("JS Error - Domain: \(error.domain), Code: \(error.code)")
            logger.error("JS Error - Description: \(error.localizedDescription)")
            if let jsError = error.userInfo["WKJavaScriptExceptionMessage"] as? String {
                logger.error("JS Exception: \(jsError)")
                throw LightweightChartError.javascriptError(jsError)
            }
            throw LightweightChartError.javascriptError(error.localizedDescription)
        }
    }
}
