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
    case pageLoaded // JS functions are available (page finished loading)
    case ready // Chart initialized and ready for data
    case visibleRangeChange
    case crosshairMove
    case markerHover
    case consoleLog
}

// MARK: - JS Data Structures

/// Visible range from JavaScript
struct JSVisibleRange: Codable, Equatable {
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

/// Marker hover data from JavaScript
struct JSMarkerHoverData {
    let markers: [JSMarkerInfo]
    let screenX: CGFloat
    let screenY: CGFloat
}

/// Individual marker info from JavaScript
struct JSMarkerInfo {
    let markerType: String  // "trade" or "mark"
    let time: Double

    // Trade-specific fields
    let isBuy: Bool?
    let symbol: String?
    let positionType: String?
    let executedQty: Double?
    let executedPrice: Double?
    let pnl: Double?
    let reason: String?

    // Mark-specific fields
    let title: String?
    let color: String?
    let category: String?
    let message: String?
    let signalType: String?
    let signalReason: String?
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

// MARK: - ChartMessageHandler

/// Handles JavaScript messages from the WebView
/// Must be a class conforming to NSObject for WKScriptMessageHandler (incompatible with @Observable)
final class ChartMessageHandler: NSObject, WKScriptMessageHandler {
    // Callbacks for different message types
    var onPageLoaded: (() -> Void)?
    var onReady: (() -> Void)?
    var onVisibleRangeChange: ((JSVisibleRange) -> Void)?
    var onCrosshairMove: ((JSCrosshairData) -> Void)?
    var onMarkerHover: ((JSMarkerHoverData?) -> Void)?
    var onConsoleLog: ((String, String) -> Void)?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let messageType = ChartMessageType(rawValue: message.name) else {
            return
        }

        // Parse message body on current thread before dispatching
        // (message.body may not be safe to access across threads)
        let body = message.body

        // Dispatch all callbacks to main thread - WKScriptMessageHandler runs on background thread
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch messageType {
            case .pageLoaded:
                self.onPageLoaded?()

            case .ready:
                self.onReady?()

            case .visibleRangeChange:
                guard let dict = body as? [String: Any],
                      let from = dict["from"] as? Double,
                      let to = dict["to"] as? Double else { return }
                self.onVisibleRangeChange?(JSVisibleRange(from: from, to: to))

            case .crosshairMove:
                let data = self.parseCrosshairData(from: body)
                self.onCrosshairMove?(data)

            case .markerHover:
                let data = self.parseMarkerHoverData(from: body)
                self.onMarkerHover?(data)

            case .consoleLog:
                guard let dict = body as? [String: Any],
                      let level = dict["level"] as? String,
                      let msg = dict["message"] as? String else { return }
                self.onConsoleLog?(level, msg)
            }
        }
    }

    private func parseCrosshairData(from body: Any) -> JSCrosshairData {
        guard let dict = body as? [String: Any] else {
            return JSCrosshairData(time: nil, price: nil, globalIndex: nil, ohlcv: nil)
        }

        let time = dict["time"] as? Double
        let price = dict["price"] as? Double
        let globalIndex = dict["globalIndex"] as? Int

        var ohlcv: JSOHLCV?
        if let ohlcvDict = dict["ohlcv"] as? [String: Any] {
            ohlcv = JSOHLCV(
                open: ohlcvDict["open"] as? Double ?? 0,
                high: ohlcvDict["high"] as? Double ?? 0,
                low: ohlcvDict["low"] as? Double ?? 0,
                close: ohlcvDict["close"] as? Double ?? 0,
                volume: ohlcvDict["volume"] as? Double ?? 0
            )
        }

        return JSCrosshairData(time: time, price: price, globalIndex: globalIndex, ohlcv: ohlcv)
    }

    private func parseMarkerHoverData(from body: Any) -> JSMarkerHoverData? {
        // Handle null/nil case (no marker hovered)
        guard let dict = body as? [String: Any] else {
            return nil
        }

        guard let markersArray = dict["markers"] as? [[String: Any]],
              let screenX = dict["screenX"] as? Double,
              let screenY = dict["screenY"] as? Double else {
            return nil
        }

        let markers = markersArray.compactMap { markerDict -> JSMarkerInfo? in
            guard let markerType = markerDict["markerType"] as? String,
                  let time = markerDict["time"] as? Double else {
                return nil
            }

            return JSMarkerInfo(
                markerType: markerType,
                time: time,
                isBuy: markerDict["isBuy"] as? Bool,
                symbol: markerDict["symbol"] as? String,
                positionType: markerDict["positionType"] as? String,
                executedQty: markerDict["executedQty"] as? Double,
                executedPrice: markerDict["executedPrice"] as? Double,
                pnl: markerDict["pnl"] as? Double,
                reason: markerDict["reason"] as? String,
                title: markerDict["title"] as? String,
                color: markerDict["color"] as? String,
                category: markerDict["category"] as? String,
                message: markerDict["message"] as? String,
                signalType: markerDict["signalType"] as? String,
                signalReason: markerDict["signalReason"] as? String
            )
        }

        return JSMarkerHoverData(
            markers: markers,
            screenX: CGFloat(screenX),
            screenY: CGFloat(screenY)
        )
    }

    /// Creates a WKUserContentController with all message handlers registered
    func createUserContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        for messageType in ChartMessageType.allCases {
            controller.add(self, name: messageType.rawValue)
        }
        return controller
    }
}

// MARK: - LightweightChartService

@Observable
final class LightweightChartService {
    var webpage: WebPage

    // Message handler (must be retained)
    private let messageHandler = ChartMessageHandler()

    // Page-loaded state management
    private var isPageLoaded = false
    private var pageLoadedContinuation: CheckedContinuation<Void, Never>?

    // Public callbacks for view layer
    var onVisibleRangeChange: ((JSVisibleRange) -> Void)?
    var onCrosshairMove: ((JSCrosshairData) -> Void)?
    var onMarkerHover: ((JSMarkerHoverData?) -> Void)?

    // MARK: - Initialization

    @MainActor
    init() {
        let scheme = URLScheme("trading")!
        let handler = DataViewDataSchemeHandler()

        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[scheme] = handler

        // Add user content controller with message handlers
        configuration.userContentController = messageHandler.createUserContentController()

        self.webpage = WebPage(configuration: configuration)

        // Setup message handler callbacks
        setupMessageHandlerCallbacks()

        webpage.load(URL(string: "trading://chart.html")!)
    }

    private func setupMessageHandlerCallbacks() {
        messageHandler.onPageLoaded = { [weak self] in
            self?.handlePageLoaded()
        }

        messageHandler.onReady = { [weak self] in
            logger.info("[Chart] Chart initialized and ready")
            _ = self // Keep reference
        }

        messageHandler.onVisibleRangeChange = { [weak self] range in
            self?.onVisibleRangeChange?(range)
        }

        messageHandler.onCrosshairMove = { [weak self] data in
            self?.onCrosshairMove?(data)
        }

        messageHandler.onMarkerHover = { [weak self] data in
            self?.onMarkerHover?(data)
        }

        messageHandler.onConsoleLog = { level, message in
            switch level {
            case "error":
                logger.error("[JS] \(message)")
            case "warn":
                logger.warning("[JS] \(message)")
            default:
                logger.info("[JS] \(message)")
            }
        }
    }

    func clearAllMarks() async throws {
        try await callJavaScript("clearAllMarkers()")
    }

    func onClean() async {
        await webpage.reload()
        isPageLoaded = false
    }

    private func handlePageLoaded() {
        logger.info("[Chart] Page loaded - JS functions available")
        isPageLoaded = true
        pageLoadedContinuation?.resume()
        pageLoadedContinuation = nil
    }

    /// Wait for the page to finish loading (JS functions become available)
    func waitForPageLoaded() async {
        if isPageLoaded { return }

        await withCheckedContinuation { continuation in
            // Check again in case loaded happened between check and continuation setup
            if isPageLoaded {
                continuation.resume()
            } else {
                pageLoadedContinuation = continuation
            }
        }
    }

    // MARK: - JavaScript API

    /// Initialize the chart with a specific type
    func initializeChart(chartType: ChartType) async throws {
        // Wait for page to load before calling JS functions
        await waitForPageLoaded()

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
