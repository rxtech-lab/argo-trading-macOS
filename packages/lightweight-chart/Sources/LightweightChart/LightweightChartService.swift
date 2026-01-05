//
//  LightweightChartService.swift
//  LightweightChart
//
//  Service for managing TradingView Lightweight Charts via WKWebView
//

import Foundation
import WebKit

// MARK: - Logger Protocol

/// Protocol for logging - allows consumers to provide their own logger
public protocol ChartLogger: Sendable {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

/// Default no-op logger
public struct DefaultChartLogger: ChartLogger, Sendable {
    public init() {}
    public func debug(_ message: String) {}
    public func info(_ message: String) {}
    public func warning(_ message: String) {}
    public func error(_ message: String) {}
}

// MARK: - URL Scheme Handler

/// URL scheme handler for loading chart resources from the package bundle
public struct ChartSchemeHandler: URLSchemeHandler {
    private let bundle: Bundle
    private let logger: ChartLogger

    public init(bundle: Bundle? = nil, logger: ChartLogger = DefaultChartLogger()) {
        // Resolve to the package bundle by default when not provided
        self.bundle = bundle ?? Bundle.module
        self.logger = logger
    }

    public func reply(
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
            logger.debug("[ChartSchemeHandler] Loading resource: \(resourceName).\(fileExtension)")

            // Load from bundle resources
            guard
                let bundleURL = bundle.url(
                    forResource: resourceName,
                    withExtension: fileExtension.isEmpty ? nil : fileExtension
                ),
                let pageData = try? Data(contentsOf: bundleURL)
            else {
                logger.error("[ChartSchemeHandler] Resource not found: \(filename)")
                continuation.finish(throwing: URLError(.fileDoesNotExist))
                return
            }

            // Determine MIME type based on file extension
            let mimeTypeValue = mimeType(for: fileExtension)

            let response = URLResponse(
                url: url,
                mimeType: mimeTypeValue,
                expectedContentLength: pageData.count,
                textEncodingName: "utf-8"
            )
            continuation.yield(.response(response))
            continuation.yield(.data(pageData))
            continuation.finish()
        }
    }
}

// MARK: - Parsing Functions (internal for testing)

/// Parse crosshair data from JavaScript message body
func parseCrosshairData(from body: Any) -> JSCrosshairData {
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

/// Parse marker hover data from JavaScript message body
func parseMarkerHoverData(from body: Any) -> JSMarkerHoverData? {
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

/// Determine MIME type for a file extension
func mimeType(for fileExtension: String) -> String {
    switch fileExtension.lowercased() {
    case "html": return "text/html"
    case "js": return "application/javascript"
    case "css": return "text/css"
    case "json": return "application/json"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "svg": return "image/svg+xml"
    default: return "application/octet-stream"
    }
}

// MARK: - ChartMessageHandler

/// Handles JavaScript messages from the WebView
/// Must be a class conforming to NSObject for WKScriptMessageHandler
public final class ChartMessageHandler: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    // Callbacks for different message types
    public var onPageLoaded: (@Sendable () -> Void)?
    public var onReady: (@Sendable () -> Void)?
    public var onVisibleRangeChange: (@Sendable (JSVisibleRange) -> Void)?
    public var onCrosshairMove: (@Sendable (JSCrosshairData) -> Void)?
    public var onMarkerHover: (@Sendable (JSMarkerHoverData?) -> Void)?
    public var onConsoleLog: (@Sendable (String, String) -> Void)?

    public override init() {
        super.init()
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let messageType = ChartMessageType(rawValue: message.name) else {
            return
        }

        // Parse message body on current thread before dispatching
        let body = message.body

        // Dispatch all callbacks to main thread
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
                let data = parseCrosshairData(from: body)
                self.onCrosshairMove?(data)

            case .markerHover:
                let data = parseMarkerHoverData(from: body)
                self.onMarkerHover?(data)

            case .consoleLog:
                guard let dict = body as? [String: Any],
                      let level = dict["level"] as? String,
                      let msg = dict["message"] as? String else { return }
                self.onConsoleLog?(level, msg)
            }
        }
    }

    /// Creates a WKUserContentController with all message handlers registered
    public func createUserContentController() -> WKUserContentController {
        let controller = WKUserContentController()
        for messageType in ChartMessageType.allCases {
            controller.add(self, name: messageType.rawValue)
        }
        return controller
    }
}

// MARK: - LightweightChartService

@Observable
@MainActor
public final class LightweightChartService {
    public var webpage: WebPage

    // Message handler (must be retained)
    private let messageHandler = ChartMessageHandler()
    private let logger: ChartLogger

    // Page-loaded state management
    private var isPageLoaded = false
    private var pageLoadedContinuation: CheckedContinuation<Void, Never>?

    // Public callbacks for view layer
    public var onVisibleRangeChange: ((JSVisibleRange) -> Void)?
    public var onCrosshairMove: ((JSCrosshairData) -> Void)?
    public var onMarkerHover: ((JSMarkerHoverData?) -> Void)?

    // MARK: - Initialization

    public init(logger: ChartLogger = DefaultChartLogger()) {
        self.logger = logger

        let scheme = URLScheme("trading")!
        let handler = ChartSchemeHandler(bundle: Bundle.module, logger: logger)

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
            Task { @MainActor in
                self?.handlePageLoaded()
            }
        }

        messageHandler.onReady = { [weak self] in
            Task { @MainActor in
                self?.logger.info("[Chart] Chart initialized and ready")
            }
        }

        messageHandler.onVisibleRangeChange = { [weak self] range in
            Task { @MainActor in
                self?.onVisibleRangeChange?(range)
            }
        }

        messageHandler.onCrosshairMove = { [weak self] data in
            Task { @MainActor in
                self?.onCrosshairMove?(data)
            }
        }

        messageHandler.onMarkerHover = { [weak self] data in
            Task { @MainActor in
                self?.onMarkerHover?(data)
            }
        }

        messageHandler.onConsoleLog = { [weak self] level, message in
            Task { @MainActor in
                guard let self else { return }
                switch level {
                case "error":
                    self.logger.error("[JS] \(message)")
                case "warn":
                    self.logger.warning("[JS] \(message)")
                default:
                    self.logger.info("[JS] \(message)")
                }
            }
        }
    }

    public func clearAllMarks() async throws {
        try await callJavaScript("clearAllMarkers()")
    }

    public func onClean() async {
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
    public func waitForPageLoaded() async {
        if isPageLoaded { return }

        await withCheckedContinuation { continuation in
            if isPageLoaded {
                continuation.resume()
            } else {
                pageLoadedContinuation = continuation
            }
        }
    }

    // MARK: - JavaScript API

    /// Initialize the chart with a specific type
    public func initializeChart(chartType: ChartType) async throws {
        await waitForPageLoaded()

        let chartTypeJS = chartType == .candlestick ? "Candlestick" : "Line"
        try await callJavaScript("initializeChart('\(chartTypeJS)')")
    }

    /// Set candlestick data
    public func setCandlestickData(_ data: [CandlestickDataJS]) async throws {
        let jsonData = try JSONEncoder().encode(data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("setCandlestickData(\(jsonString))")
    }

    /// Set line data
    public func setLineData(_ data: [LineDataJS]) async throws {
        let jsonData = try JSONEncoder().encode(data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("setLineData(\(jsonString))")
    }

    /// Update a single candlestick data point
    public func updateCandlestickData(_ data: CandlestickDataJS) async throws {
        let jsonData = try JSONEncoder().encode(data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("updateCandlestickData(\(jsonString))")
    }

    /// Update a single line data point
    public func updateLineData(_ data: LineDataJS) async throws {
        let jsonData = try JSONEncoder().encode(data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode data")
        }
        try await callJavaScript("updateLineData(\(jsonString))")
    }

    /// Set markers on the chart
    public func setMarkers(_ markers: [MarkerDataJS]) async throws {
        let jsonData = try JSONEncoder().encode(markers)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode markers")
        }
        try await callJavaScript("setMarkers(\(jsonString))")
    }

    /// Toggle visibility of markers by type
    public func setMarkersVisible(_ visible: Bool, type: String) async throws {
        try await callJavaScript("setMarkersVisible(\(visible), '\(type)')")
    }

    /// Scroll to a specific timestamp
    public func scrollToTime(_ timestamp: Date) async throws {
        let time = timestamp.timeIntervalSince1970
        try await callJavaScript("scrollToTime(\(time))")
    }

    /// Set the visible logical range
    public func setVisibleRange(from: Int, to: Int) async throws {
        try await callJavaScript("setVisibleRange(\(from), \(to))")
    }

    /// Resize the chart
    public func resize(width: CGFloat, height: CGFloat) async throws {
        try await callJavaScript("resizeChart(\(width), \(height))")
    }

    /// Fit all content in view
    public func fitContent() async throws {
        try await callJavaScript("fitContent()")
    }

    /// Scroll to the latest (realtime) data
    public func scrollToRealtime() async throws {
        try await callJavaScript("scrollToRealtime()")
    }

    /// Set volume series visibility
    public func setVolumeVisible(_ visible: Bool) async throws {
        try await callJavaScript("setVolumeVisible(\(visible))")
    }

    /// Switch chart type
    public func switchChartType(_ chartType: ChartType) async throws {
        let chartTypeJS = chartType == .candlestick ? "Candlestick" : "Line"
        try await callJavaScript("switchChartType('\(chartTypeJS)')")
    }

    // MARK: - Indicators

    /// Set indicator configuration on the chart
    public func setIndicators(_ settings: IndicatorSettings) async throws {
        let enabledIndicators = settings.enabledIndicators
        if enabledIndicators.isEmpty {
            try await callJavaScript("clearIndicators()")
            return
        }

        let jsonData = try JSONEncoder().encode(settings)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw LightweightChartError.javascriptError("Failed to encode indicator settings")
        }
        try await callJavaScript("setIndicators(\(jsonString))")
    }

    /// Clear all indicators from the chart
    public func clearIndicators() async throws {
        try await callJavaScript("clearIndicators()")
    }

    // MARK: - Private Helpers

    @discardableResult
    private func callJavaScript(_ js: String) async throws -> Any? {
        do {
            return try await webpage.callJavaScript(js)
        } catch let error as NSError {
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

