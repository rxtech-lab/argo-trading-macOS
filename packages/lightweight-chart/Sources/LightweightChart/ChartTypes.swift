//
//  ChartTypes.swift
//  LightweightChart
//
//  Types for LightweightChart package
//

import Foundation

/// Price data for a single ticker
public struct PriceData: Codable, Hashable, Identifiable {
    public let globalIndex: Int
    public let date: Date
    public let ticker: String
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public var id: Int { globalIndex }

    public init(
        globalIndex: Int, date: Date, ticker: String, open: Double, high: Double, low: Double,
        close: Double, volume: Double
    ) {
        self.globalIndex = globalIndex
        self.date = date
        self.ticker = ticker
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

// MARK: - Message Types

/// Message types sent from JavaScript to Swift
public enum ChartMessageType: String, CaseIterable, Sendable {
    case pageLoaded  // JS functions are available (page finished loading)
    case ready  // Chart initialized and ready for data
    case visibleRangeChange
    case crosshairMove
    case markerHover
    case consoleLog
}

// MARK: - JS Data Structures

/// Visible range from JavaScript
public struct JSVisibleRange: Codable, Equatable, Sendable {
    public let from: Double
    public let to: Double

    public init(from: Double, to: Double) {
        self.from = from
        self.to = to
    }
}

/// Crosshair data from JavaScript
public struct JSCrosshairData: Sendable {
    public let time: Double?
    public let price: Double?
    public let globalIndex: Int?
    public let ohlcv: JSOHLCV?

    public init(time: Double?, price: Double?, globalIndex: Int?, ohlcv: JSOHLCV?) {
        self.time = time
        self.price = price
        self.globalIndex = globalIndex
        self.ohlcv = ohlcv
    }
}

/// OHLCV data from JavaScript
public struct JSOHLCV: Sendable {
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public init(open: Double, high: Double, low: Double, close: Double, volume: Double) {
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}

/// Marker hover data from JavaScript
public struct JSMarkerHoverData: Sendable {
    public let markers: [JSMarkerInfo]
    public let screenX: CGFloat
    public let screenY: CGFloat

    public init(markers: [JSMarkerInfo], screenX: CGFloat, screenY: CGFloat) {
        self.markers = markers
        self.screenX = screenX
        self.screenY = screenY
    }
}

/// Individual marker info from JavaScript
public struct JSMarkerInfo: Sendable {
    public let markerType: String  // "trade" or "mark"
    public let time: Double

    // Trade-specific fields
    public let isBuy: Bool?
    public let symbol: String?
    public let positionType: String?
    public let executedQty: Double?
    public let executedPrice: Double?
    public let pnl: Double?
    public let reason: String?

    // Mark-specific fields
    public let title: String?
    public let color: String?
    public let category: String?
    public let message: String?
    public let signalType: String?
    public let signalReason: String?

    public init(
        markerType: String,
        time: Double,
        isBuy: Bool? = nil,
        symbol: String? = nil,
        positionType: String? = nil,
        executedQty: Double? = nil,
        executedPrice: Double? = nil,
        pnl: Double? = nil,
        reason: String? = nil,
        title: String? = nil,
        color: String? = nil,
        category: String? = nil,
        message: String? = nil,
        signalType: String? = nil,
        signalReason: String? = nil
    ) {
        self.markerType = markerType
        self.time = time
        self.isBuy = isBuy
        self.symbol = symbol
        self.positionType = positionType
        self.executedQty = executedQty
        self.executedPrice = executedPrice
        self.pnl = pnl
        self.reason = reason
        self.title = title
        self.color = color
        self.category = category
        self.message = message
        self.signalType = signalType
        self.signalReason = signalReason
    }
}

// MARK: - Chart Type

/// Chart display type
public enum ChartType: String, CaseIterable, Identifiable, Sendable {
    case line = "Line"
    case candlestick = "Candlestick"

    public var id: String { rawValue }
}

// MARK: - Candlestick Data

/// Candlestick data for JavaScript
public struct CandlestickDataJS: Codable, Sendable {
    public let time: Double
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let globalIndex: Int
    public let volume: Double

    public init(
        time: Double, open: Double, high: Double, low: Double, close: Double, globalIndex: Int,
        volume: Double
    ) {
        self.time = time
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.globalIndex = globalIndex
        self.volume = volume
    }
}

/// Line data for JavaScript
public struct LineDataJS: Codable, Sendable {
    public let time: Double
    public let value: Double
    public let globalIndex: Int
    public let volume: Double

    public init(time: Double, value: Double, globalIndex: Int, volume: Double) {
        self.time = time
        self.value = value
        self.globalIndex = globalIndex
        self.volume = volume
    }
}

/// Marker data for JavaScript
public struct MarkerDataJS: Codable, Sendable, Equatable {
    public let time: Double
    public let position: String
    public let color: String
    public let shape: String
    public let text: String
    public let id: String
    public let markerType: String

    // Trade-specific fields
    public var isBuy: Bool?
    public var symbol: String?
    public var positionType: String?
    public var executedQty: Double?
    public var executedPrice: Double?
    public var pnl: Double?
    public var reason: String?

    // Mark-specific fields
    public var title: String?
    public var category: String?
    public var message: String?
    public var signalType: String?
    public var signalReason: String?

    public init(
        time: Double,
        position: String,
        color: String,
        shape: String,
        text: String,
        id: String,
        markerType: String,
        isBuy: Bool? = nil,
        symbol: String? = nil,
        positionType: String? = nil,
        executedQty: Double? = nil,
        executedPrice: Double? = nil,
        pnl: Double? = nil,
        reason: String? = nil,
        title: String? = nil,
        category: String? = nil,
        message: String? = nil,
        signalType: String? = nil,
        signalReason: String? = nil
    ) {
        self.time = time
        self.position = position
        self.color = color
        self.shape = shape
        self.text = text
        self.id = id
        self.markerType = markerType
        self.isBuy = isBuy
        self.symbol = symbol
        self.positionType = positionType
        self.executedQty = executedQty
        self.executedPrice = executedPrice
        self.pnl = pnl
        self.reason = reason
        self.title = title
        self.category = category
        self.message = message
        self.signalType = signalType
        self.signalReason = signalReason
    }
}

// MARK: - Visible Range

/// Represents the visible logical range of the chart
public struct VisibleLogicalRange: Sendable {
    public let localFromIndex: Int
    public let localToIndex: Int

    public init(localFromIndex: Int, localToIndex: Int) {
        self.localFromIndex = localFromIndex
        self.localToIndex = localToIndex
    }

    /// Distance from the beginning (negative if scrolled past start)
    public var distanceFromStart: Int { localFromIndex }

    /// Whether near the start (within threshold)
    public func isNearStart(threshold: Int = 10) -> Bool {
        localFromIndex < threshold
    }

    public func isNearEnd(threshold: Int = 10, totalCount: Int) -> Bool {
        let distance = totalCount - localToIndex
        return distance < threshold
    }
}

// MARK: - Indicator Types

/// Types of technical indicators supported by the chart
public enum IndicatorType: String, CaseIterable, Identifiable, Codable, Sendable {
    case sma = "SMA"
    case ema = "EMA"
    case vwap = "VWAP"
    case rsi = "RSI"
    case macd = "MACD"

    public var id: String { rawValue }

    /// Display name for UI
    public var displayName: String { rawValue }

    /// Whether this indicator overlays on the price chart or needs a separate pane
    public var isOverlay: Bool {
        switch self {
        case .sma, .ema, .vwap:
            return true
        case .rsi, .macd:
            return false
        }
    }

    /// Default parameters for this indicator type
    public var defaultParameters: [String: Int] {
        switch self {
        case .sma:
            return ["period": 20]
        case .ema:
            return ["period": 12]
        case .vwap:
            return [:]
        case .rsi:
            return ["period": 14]
        case .macd:
            return ["fastPeriod": 12, "slowPeriod": 26, "signalPeriod": 9]
        }
    }

    /// System image for the indicator
    public var systemImage: String {
        switch self {
        case .sma, .ema:
            return "chart.line.uptrend.xyaxis"
        case .vwap:
            return "chart.bar.fill"
        case .rsi:
            return "gauge.with.needle"
        case .macd:
            return "waveform.path.ecg"
        }
    }

    /// Default color for the indicator line (hex string)
    public var defaultColor: String {
        switch self {
        case .sma:
            return "#FF9800"
        case .ema:
            return "#2196F3"
        case .vwap:
            return "#9C27B0"
        case .rsi:
            return "#4CAF50"
        case .macd:
            return "#E91E63"
        }
    }
}

/// Configuration for a single indicator instance
public struct IndicatorConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let type: IndicatorType
    public var isEnabled: Bool
    public var parameters: [String: Int]
    public var color: String

    public init(type: IndicatorType, isEnabled: Bool = false) {
        self.id = UUID()
        self.type = type
        self.isEnabled = isEnabled
        self.color = type.defaultColor
        self.parameters = type.defaultParameters
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: IndicatorConfig, rhs: IndicatorConfig) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled && lhs.parameters == rhs.parameters
            && lhs.color == rhs.color
    }
}

/// Container for all indicator configurations
public struct IndicatorSettings: Codable, Equatable, Sendable {
    public var indicators: [IndicatorConfig]

    public init(indicators: [IndicatorConfig]) {
        self.indicators = indicators
    }

    /// Get enabled indicators only
    public var enabledIndicators: [IndicatorConfig] {
        indicators.filter { $0.isEnabled }
    }

    /// Default settings with all indicators disabled
    public static var `default`: IndicatorSettings {
        IndicatorSettings(
            indicators: IndicatorType.allCases.map { IndicatorConfig(type: $0, isEnabled: false) }
        )
    }

    /// Encode to JSON Data for AppStorage
    public func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decode from JSON Data
    public static func fromData(_ data: Data?) -> IndicatorSettings {
        guard let data = data,
            let settings = try? JSONDecoder().decode(IndicatorSettings.self, from: data)
        else {
            return .default
        }
        return settings
    }
}

// MARK: - Errors

public enum LightweightChartError: Error, LocalizedError, Sendable {
    case webViewNotConfigured
    case javascriptError(String)
    case resourceNotFound(String)

    public var errorDescription: String? {
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

// MARK: - PriceData Conversions

extension PriceData {
    /// Convert to CandlestickDataJS for JavaScript chart
    public func toCandlestickJS() -> CandlestickDataJS {
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

    /// Convert to LineDataJS for JavaScript chart (uses close price as value)
    public func toLineJS() -> LineDataJS {
        LineDataJS(
            time: date.timeIntervalSince1970,
            value: close,
            globalIndex: globalIndex,
            volume: volume
        )
    }
}
