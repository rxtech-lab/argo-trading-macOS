//
//  LightweightChartTests.swift
//  LightweightChart
//
//  Tests for LightweightChart package
//

import Foundation
import Testing
@testable import LightweightChart

// MARK: - ChartTypes Tests

@Suite("ChartType Tests")
struct ChartTypeTests {
    @Test("ChartType has correct raw values")
    func chartTypeRawValues() {
        #expect(ChartType.line.rawValue == "Line")
        #expect(ChartType.candlestick.rawValue == "Candlestick")
    }

    @Test("ChartType is identifiable")
    func chartTypeIdentifiable() {
        #expect(ChartType.line.id == "Line")
        #expect(ChartType.candlestick.id == "Candlestick")
    }

    @Test("ChartType allCases contains both types")
    func chartTypeAllCases() {
        #expect(ChartType.allCases.count == 2)
        #expect(ChartType.allCases.contains(.line))
        #expect(ChartType.allCases.contains(.candlestick))
    }
}

// MARK: - JSVisibleRange Tests

@Suite("JSVisibleRange Tests")
struct JSVisibleRangeTests {
    @Test("JSVisibleRange equality")
    func visibleRangeEquality() {
        let range1 = JSVisibleRange(from: 0, to: 100)
        let range2 = JSVisibleRange(from: 0, to: 100)
        let range3 = JSVisibleRange(from: 10, to: 50)

        #expect(range1 == range2)
        #expect(range1 != range3)
    }

    @Test("JSVisibleRange is codable")
    func visibleRangeCodable() throws {
        let original = JSVisibleRange(from: 10.5, to: 99.5)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSVisibleRange.self, from: encoded)

        #expect(decoded == original)
    }
}

// MARK: - VisibleLogicalRange Tests

@Suite("VisibleLogicalRange Tests")
struct VisibleLogicalRangeTests {
    @Test("isNearStart returns true when close to start")
    func isNearStart() {
        let range = VisibleLogicalRange(localFromIndex: 5, localToIndex: 50)
        #expect(range.isNearStart(threshold: 10))
        #expect(!range.isNearStart(threshold: 3))
    }

    @Test("isNearEnd returns true when close to end")
    func isNearEnd() {
        let range = VisibleLogicalRange(localFromIndex: 90, localToIndex: 97)
        #expect(range.isNearEnd(threshold: 10, totalCount: 100))
        #expect(!range.isNearEnd(threshold: 2, totalCount: 100))
    }

    @Test("distanceFromStart returns localFromIndex")
    func distanceFromStart() {
        let range = VisibleLogicalRange(localFromIndex: 25, localToIndex: 75)
        #expect(range.distanceFromStart == 25)
    }
}

// MARK: - CandlestickDataJS Tests

@Suite("CandlestickDataJS Tests")
struct CandlestickDataJSTests {
    @Test("CandlestickDataJS is codable")
    func candlestickDataCodable() throws {
        let original = CandlestickDataJS(
            time: 1704067200,
            open: 100.0,
            high: 110.0,
            low: 95.0,
            close: 105.0,
            globalIndex: 42,
            volume: 1000000
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CandlestickDataJS.self, from: encoded)

        #expect(decoded.time == original.time)
        #expect(decoded.open == original.open)
        #expect(decoded.high == original.high)
        #expect(decoded.low == original.low)
        #expect(decoded.close == original.close)
        #expect(decoded.globalIndex == original.globalIndex)
        #expect(decoded.volume == original.volume)
    }
}

// MARK: - LineDataJS Tests

@Suite("LineDataJS Tests")
struct LineDataJSTests {
    @Test("LineDataJS is codable")
    func lineDataCodable() throws {
        let original = LineDataJS(
            time: 1704067200,
            value: 105.0,
            globalIndex: 42,
            volume: 1000000
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LineDataJS.self, from: encoded)

        #expect(decoded.time == original.time)
        #expect(decoded.value == original.value)
        #expect(decoded.globalIndex == original.globalIndex)
        #expect(decoded.volume == original.volume)
    }
}

// MARK: - MarkerDataJS Tests

@Suite("MarkerDataJS Tests")
struct MarkerDataJSTests {
    @Test("MarkerDataJS trade marker is codable")
    func tradeMarkerCodable() throws {
        var original = MarkerDataJS(
            time: 1704067200,
            position: "aboveBar",
            color: "#26a69a",
            shape: "arrowDown",
            text: "B",
            id: "trade-1",
            markerType: "trade"
        )
        original.isBuy = true
        original.symbol = "BTCUSDT"
        original.executedPrice = 42000.0

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarkerDataJS.self, from: encoded)

        #expect(decoded.time == original.time)
        #expect(decoded.markerType == "trade")
        #expect(decoded.isBuy == true)
        #expect(decoded.symbol == "BTCUSDT")
    }

    @Test("MarkerDataJS mark marker is codable")
    func markMarkerCodable() throws {
        var original = MarkerDataJS(
            time: 1704067200,
            position: "belowBar",
            color: "#ffc107",
            shape: "circle",
            text: "R",
            id: "mark-1",
            markerType: "mark"
        )
        original.title = "RSI Signal"
        original.category = "Technical"
        original.signalType = "BUY"

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MarkerDataJS.self, from: encoded)

        #expect(decoded.markerType == "mark")
        #expect(decoded.title == "RSI Signal")
        #expect(decoded.category == "Technical")
    }
}

// MARK: - IndicatorType Tests

@Suite("IndicatorType Tests")
struct IndicatorTypeTests {
    @Test("IndicatorType has correct raw values")
    func indicatorTypeRawValues() {
        #expect(IndicatorType.sma.rawValue == "SMA")
        #expect(IndicatorType.ema.rawValue == "EMA")
        #expect(IndicatorType.vwap.rawValue == "VWAP")
        #expect(IndicatorType.rsi.rawValue == "RSI")
        #expect(IndicatorType.macd.rawValue == "MACD")
    }

    @Test("IndicatorType overlay indicators")
    func indicatorTypeIsOverlay() {
        #expect(IndicatorType.sma.isOverlay == true)
        #expect(IndicatorType.ema.isOverlay == true)
        #expect(IndicatorType.vwap.isOverlay == true)
        #expect(IndicatorType.rsi.isOverlay == false)
        #expect(IndicatorType.macd.isOverlay == false)
    }

    @Test("IndicatorType has default parameters")
    func indicatorTypeDefaultParameters() {
        #expect(IndicatorType.sma.defaultParameters["period"] == 20)
        #expect(IndicatorType.ema.defaultParameters["period"] == 12)
        #expect(IndicatorType.rsi.defaultParameters["period"] == 14)
        #expect(IndicatorType.macd.defaultParameters["fastPeriod"] == 12)
        #expect(IndicatorType.macd.defaultParameters["slowPeriod"] == 26)
        #expect(IndicatorType.macd.defaultParameters["signalPeriod"] == 9)
    }

    @Test("IndicatorType has default colors")
    func indicatorTypeDefaultColors() {
        #expect(IndicatorType.sma.defaultColor == "#FF9800")
        #expect(IndicatorType.ema.defaultColor == "#2196F3")
        #expect(IndicatorType.vwap.defaultColor == "#9C27B0")
        #expect(IndicatorType.rsi.defaultColor == "#4CAF50")
        #expect(IndicatorType.macd.defaultColor == "#E91E63")
    }
}

// MARK: - IndicatorConfig Tests

@Suite("IndicatorConfig Tests")
struct IndicatorConfigTests {
    @Test("IndicatorConfig initializes with type defaults")
    func indicatorConfigInit() {
        let config = IndicatorConfig(type: .sma)

        #expect(config.type == .sma)
        #expect(config.isEnabled == false)
        #expect(config.color == "#FF9800")
        #expect(config.parameters["period"] == 20)
    }

    @Test("IndicatorConfig equality is based on UUID, not just type")
    func indicatorConfigEquality() {
        let config1 = IndicatorConfig(type: .sma, isEnabled: true)
        let config2 = IndicatorConfig(type: .sma, isEnabled: true)

        // Each IndicatorConfig gets a unique UUID on creation, 
        // so two configs with same type are not equal
        #expect(config1 != config2)

        // Assigning to a new variable copies the same UUID, so they are equal
        let config3 = config1
        #expect(config1 == config3)
    }

    @Test("IndicatorConfig is codable")
    func indicatorConfigCodable() throws {
        let original = IndicatorConfig(type: .rsi, isEnabled: true)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IndicatorConfig.self, from: encoded)

        #expect(decoded.type == original.type)
        #expect(decoded.isEnabled == original.isEnabled)
        #expect(decoded.id == original.id)
    }
}

// MARK: - IndicatorSettings Tests

@Suite("IndicatorSettings Tests")
struct IndicatorSettingsTests {
    @Test("IndicatorSettings default has all indicators disabled")
    func indicatorSettingsDefault() {
        let settings = IndicatorSettings.default

        #expect(settings.indicators.count == IndicatorType.allCases.count)
        #expect(settings.enabledIndicators.isEmpty)

        for config in settings.indicators {
            #expect(config.isEnabled == false)
        }
    }

    @Test("IndicatorSettings enabledIndicators filters correctly")
    func indicatorSettingsEnabledIndicators() {
        var settings = IndicatorSettings.default
        settings.indicators[0].isEnabled = true
        settings.indicators[2].isEnabled = true

        #expect(settings.enabledIndicators.count == 2)
    }

    @Test("IndicatorSettings toData and fromData roundtrip")
    func indicatorSettingsDataRoundtrip() {
        var original = IndicatorSettings.default
        original.indicators[0].isEnabled = true

        let data = original.toData()
        #expect(data != nil)

        let restored = IndicatorSettings.fromData(data)
        #expect(restored.indicators[0].isEnabled == true)
    }

    @Test("IndicatorSettings fromData returns default for nil")
    func indicatorSettingsFromNilData() {
        let settings = IndicatorSettings.fromData(nil)
        #expect(settings.indicators.count == IndicatorType.allCases.count)
    }
}

// MARK: - LightweightChartError Tests

@Suite("LightweightChartError Tests")
struct LightweightChartErrorTests {
    @Test("LightweightChartError has correct descriptions")
    func errorDescriptions() {
        let webViewError = LightweightChartError.webViewNotConfigured
        #expect(webViewError.errorDescription == "WebView is not configured")

        let jsError = LightweightChartError.javascriptError("Test error")
        #expect(jsError.errorDescription == "JavaScript error: Test error")

        let resourceError = LightweightChartError.resourceNotFound("chart.html")
        #expect(resourceError.errorDescription == "Resource not found: chart.html")
    }
}

// MARK: - JSMarkerInfo Tests

@Suite("JSMarkerInfo Tests")
struct JSMarkerInfoTests {
    @Test("JSMarkerInfo trade marker initialization")
    func tradeMarkerInit() {
        let marker = JSMarkerInfo(
            markerType: "trade",
            time: 1704067200,
            isBuy: true,
            symbol: "BTCUSDT",
            positionType: "LONG",
            executedQty: 0.5,
            executedPrice: 42000.0,
            pnl: 500.0,
            reason: "RSI oversold"
        )

        #expect(marker.markerType == "trade")
        #expect(marker.isBuy == true)
        #expect(marker.symbol == "BTCUSDT")
        #expect(marker.executedPrice == 42000.0)
    }

    @Test("JSMarkerInfo mark marker initialization")
    func markMarkerInit() {
        let marker = JSMarkerInfo(
            markerType: "mark",
            time: 1704067200,
            title: "Signal",
            color: "#ffc107",
            category: "Technical",
            message: "Test message",
            signalType: "BUY",
            signalReason: "Indicator triggered"
        )

        #expect(marker.markerType == "mark")
        #expect(marker.title == "Signal")
        #expect(marker.color == "#ffc107")
        #expect(marker.signalType == "BUY")
    }
}

// MARK: - JSCrosshairData Tests

@Suite("JSCrosshairData Tests")
struct JSCrosshairDataTests {
    @Test("JSCrosshairData initialization with all values")
    func crosshairDataInit() {
        let ohlcv = JSOHLCV(open: 100, high: 110, low: 95, close: 105, volume: 1000000)
        let data = JSCrosshairData(time: 1704067200, price: 105.0, globalIndex: 42, ohlcv: ohlcv)

        #expect(data.time == 1704067200)
        #expect(data.price == 105.0)
        #expect(data.globalIndex == 42)
        #expect(data.ohlcv?.close == 105)
    }

    @Test("JSCrosshairData initialization with nil values")
    func crosshairDataNilInit() {
        let data = JSCrosshairData(time: nil, price: nil, globalIndex: nil, ohlcv: nil)

        #expect(data.time == nil)
        #expect(data.price == nil)
        #expect(data.globalIndex == nil)
        #expect(data.ohlcv == nil)
    }
}

// MARK: - ChartMessageType Tests

@Suite("ChartMessageType Tests")
struct ChartMessageTypeTests {
    @Test("ChartMessageType has all expected cases")
    func messageTypeAllCases() {
        let allCases = ChartMessageType.allCases

        #expect(allCases.contains(.pageLoaded))
        #expect(allCases.contains(.ready))
        #expect(allCases.contains(.visibleRangeChange))
        #expect(allCases.contains(.crosshairMove))
        #expect(allCases.contains(.markerHover))
        #expect(allCases.contains(.consoleLog))
    }

    @Test("ChartMessageType raw values match JS message names")
    func messageTypeRawValues() {
        #expect(ChartMessageType.pageLoaded.rawValue == "pageLoaded")
        #expect(ChartMessageType.ready.rawValue == "ready")
        #expect(ChartMessageType.visibleRangeChange.rawValue == "visibleRangeChange")
        #expect(ChartMessageType.crosshairMove.rawValue == "crosshairMove")
        #expect(ChartMessageType.markerHover.rawValue == "markerHover")
        #expect(ChartMessageType.consoleLog.rawValue == "consoleLog")
    }
}

// MARK: - Crosshair Data Parsing Tests

@Suite("Crosshair Data Parsing Tests")
struct CrosshairDataParsingTests {
    @Test("parseCrosshairData returns empty data for non-dictionary input")
    func parseNonDictionary() {
        let result = parseCrosshairData(from: "invalid")
        #expect(result.time == nil)
        #expect(result.price == nil)
        #expect(result.globalIndex == nil)
        #expect(result.ohlcv == nil)
    }

    @Test("parseCrosshairData returns empty data for empty dictionary")
    func parseEmptyDictionary() {
        let result = parseCrosshairData(from: [:] as [String: Any])
        #expect(result.time == nil)
        #expect(result.price == nil)
        #expect(result.globalIndex == nil)
        #expect(result.ohlcv == nil)
    }

    @Test("parseCrosshairData parses time correctly")
    func parseTime() {
        let input: [String: Any] = ["time": 1704067200.0]
        let result = parseCrosshairData(from: input)
        #expect(result.time == 1704067200.0)
    }

    @Test("parseCrosshairData parses price correctly")
    func parsePrice() {
        let input: [String: Any] = ["price": 42000.50]
        let result = parseCrosshairData(from: input)
        #expect(result.price == 42000.50)
    }

    @Test("parseCrosshairData parses globalIndex correctly")
    func parseGlobalIndex() {
        let input: [String: Any] = ["globalIndex": 42]
        let result = parseCrosshairData(from: input)
        #expect(result.globalIndex == 42)
    }

    @Test("parseCrosshairData parses complete OHLCV data")
    func parseOHLCV() {
        let ohlcvDict: [String: Any] = [
            "open": 100.0,
            "high": 110.0,
            "low": 95.0,
            "close": 105.0,
            "volume": 1000000.0
        ]
        let input: [String: Any] = ["ohlcv": ohlcvDict]
        let result = parseCrosshairData(from: input)

        #expect(result.ohlcv != nil)
        #expect(result.ohlcv?.open == 100.0)
        #expect(result.ohlcv?.high == 110.0)
        #expect(result.ohlcv?.low == 95.0)
        #expect(result.ohlcv?.close == 105.0)
        #expect(result.ohlcv?.volume == 1000000.0)
    }

    @Test("parseCrosshairData handles partial OHLCV data with defaults")
    func parsePartialOHLCV() {
        let ohlcvDict: [String: Any] = ["open": 100.0, "close": 105.0]
        let input: [String: Any] = ["ohlcv": ohlcvDict]
        let result = parseCrosshairData(from: input)

        #expect(result.ohlcv?.open == 100.0)
        #expect(result.ohlcv?.high == 0)
        #expect(result.ohlcv?.low == 0)
        #expect(result.ohlcv?.close == 105.0)
        #expect(result.ohlcv?.volume == 0)
    }

    @Test("parseCrosshairData parses complete data")
    func parseCompleteData() {
        let ohlcvDict: [String: Any] = [
            "open": 100.0, "high": 110.0, "low": 95.0,
            "close": 105.0, "volume": 1000000.0
        ]
        let input: [String: Any] = [
            "time": 1704067200.0,
            "price": 105.0,
            "globalIndex": 42,
            "ohlcv": ohlcvDict
        ]
        let result = parseCrosshairData(from: input)

        #expect(result.time == 1704067200.0)
        #expect(result.price == 105.0)
        #expect(result.globalIndex == 42)
        #expect(result.ohlcv?.close == 105.0)
    }
}

// MARK: - Marker Hover Data Parsing Tests

@Suite("Marker Hover Data Parsing Tests")
struct MarkerHoverDataParsingTests {
    @Test("parseMarkerHoverData returns nil for non-dictionary input")
    func parseNonDictionary() {
        let result = parseMarkerHoverData(from: "invalid")
        #expect(result == nil)
    }

    @Test("parseMarkerHoverData returns nil for empty dictionary")
    func parseEmptyDictionary() {
        let result = parseMarkerHoverData(from: [:] as [String: Any])
        #expect(result == nil)
    }

    @Test("parseMarkerHoverData returns nil when markers array is missing")
    func parseMissingMarkers() {
        let input: [String: Any] = [
            "screenX": 100.0,
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)
        #expect(result == nil)
    }

    @Test("parseMarkerHoverData returns nil when screenX is missing")
    func parseMissingScreenX() {
        let input: [String: Any] = [
            "markers": [] as [[String: Any]],
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)
        #expect(result == nil)
    }

    @Test("parseMarkerHoverData returns nil when screenY is missing")
    func parseMissingScreenY() {
        let input: [String: Any] = [
            "markers": [] as [[String: Any]],
            "screenX": 100.0
        ]
        let result = parseMarkerHoverData(from: input)
        #expect(result == nil)
    }

    @Test("parseMarkerHoverData parses empty markers array")
    func parseEmptyMarkersArray() {
        let input: [String: Any] = [
            "markers": [] as [[String: Any]],
            "screenX": 100.0,
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)

        #expect(result != nil)
        #expect(result?.markers.isEmpty == true)
        #expect(result?.screenX == 100.0)
        #expect(result?.screenY == 200.0)
    }

    @Test("parseMarkerHoverData parses trade marker")
    func parseTradeMarker() {
        let markerDict: [String: Any] = [
            "markerType": "trade",
            "time": 1704067200.0,
            "isBuy": true,
            "symbol": "BTCUSDT",
            "positionType": "LONG",
            "executedQty": 0.5,
            "executedPrice": 42000.0,
            "pnl": 500.0,
            "reason": "RSI oversold"
        ]
        let input: [String: Any] = [
            "markers": [markerDict],
            "screenX": 150.0,
            "screenY": 250.0
        ]
        let result = parseMarkerHoverData(from: input)

        #expect(result != nil)
        #expect(result?.markers.count == 1)

        let marker = result?.markers.first
        #expect(marker?.markerType == "trade")
        #expect(marker?.time == 1704067200.0)
        #expect(marker?.isBuy == true)
        #expect(marker?.symbol == "BTCUSDT")
        #expect(marker?.positionType == "LONG")
        #expect(marker?.executedQty == 0.5)
        #expect(marker?.executedPrice == 42000.0)
        #expect(marker?.pnl == 500.0)
        #expect(marker?.reason == "RSI oversold")
    }

    @Test("parseMarkerHoverData parses mark marker")
    func parseMarkMarker() {
        let markerDict: [String: Any] = [
            "markerType": "mark",
            "time": 1704067200.0,
            "title": "RSI Signal",
            "color": "#ffc107",
            "category": "Technical",
            "message": "RSI crossed threshold",
            "signalType": "BUY",
            "signalReason": "RSI < 30"
        ]
        let input: [String: Any] = [
            "markers": [markerDict],
            "screenX": 150.0,
            "screenY": 250.0
        ]
        let result = parseMarkerHoverData(from: input)

        #expect(result != nil)
        let marker = result?.markers.first
        #expect(marker?.markerType == "mark")
        #expect(marker?.title == "RSI Signal")
        #expect(marker?.color == "#ffc107")
        #expect(marker?.category == "Technical")
        #expect(marker?.message == "RSI crossed threshold")
        #expect(marker?.signalType == "BUY")
        #expect(marker?.signalReason == "RSI < 30")
    }

    @Test("parseMarkerHoverData parses multiple markers")
    func parseMultipleMarkers() {
        let tradeMarker: [String: Any] = [
            "markerType": "trade",
            "time": 1704067200.0
        ]
        let markMarker: [String: Any] = [
            "markerType": "mark",
            "time": 1704067300.0
        ]
        let input: [String: Any] = [
            "markers": [tradeMarker, markMarker],
            "screenX": 100.0,
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)

        #expect(result?.markers.count == 2)
    }

    @Test("parseMarkerHoverData filters out invalid markers")
    func parseFiltersInvalidMarkers() {
        let validMarker: [String: Any] = [
            "markerType": "trade",
            "time": 1704067200.0
        ]
        let invalidMarker: [String: Any] = [
            "markerType": "trade"
            // missing required 'time' field
        ]
        let input: [String: Any] = [
            "markers": [validMarker, invalidMarker],
            "screenX": 100.0,
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)

        #expect(result?.markers.count == 1)
    }

    @Test("parseMarkerHoverData handles markers with missing optional fields")
    func parseMarkersWithMissingOptionalFields() {
        let markerDict: [String: Any] = [
            "markerType": "trade",
            "time": 1704067200.0
        ]
        let input: [String: Any] = [
            "markers": [markerDict],
            "screenX": 100.0,
            "screenY": 200.0
        ]
        let result = parseMarkerHoverData(from: input)

        let marker = result?.markers.first
        #expect(marker?.isBuy == nil)
        #expect(marker?.symbol == nil)
        #expect(marker?.executedPrice == nil)
    }
}

// MARK: - MIME Type Tests

@Suite("MIME Type Tests")
struct MIMETypeTests {
    @Test("HTML files return text/html")
    func htmlMimeType() {
        #expect(mimeType(for: "html") == "text/html")
        #expect(mimeType(for: "HTML") == "text/html")
    }

    @Test("JavaScript files return application/javascript")
    func jsMimeType() {
        #expect(mimeType(for: "js") == "application/javascript")
        #expect(mimeType(for: "JS") == "application/javascript")
    }

    @Test("CSS files return text/css")
    func cssMimeType() {
        #expect(mimeType(for: "css") == "text/css")
    }

    @Test("JSON files return application/json")
    func jsonMimeType() {
        #expect(mimeType(for: "json") == "application/json")
    }

    @Test("PNG files return image/png")
    func pngMimeType() {
        #expect(mimeType(for: "png") == "image/png")
    }

    @Test("JPEG files return image/jpeg")
    func jpegMimeType() {
        #expect(mimeType(for: "jpg") == "image/jpeg")
        #expect(mimeType(for: "jpeg") == "image/jpeg")
        #expect(mimeType(for: "JPEG") == "image/jpeg")
    }

    @Test("SVG files return image/svg+xml")
    func svgMimeType() {
        #expect(mimeType(for: "svg") == "image/svg+xml")
    }

    @Test("Unknown extensions return application/octet-stream")
    func unknownMimeType() {
        #expect(mimeType(for: "xyz") == "application/octet-stream")
        #expect(mimeType(for: "") == "application/octet-stream")
        #expect(mimeType(for: "txt") == "application/octet-stream")
    }
}

// MARK: - DefaultChartLogger Tests

@Suite("DefaultChartLogger Tests")
struct DefaultChartLoggerTests {
    @Test("DefaultChartLogger can be instantiated")
    func defaultLoggerInit() {
        let logger = DefaultChartLogger()
        #expect(logger is ChartLogger)
    }

    @Test("DefaultChartLogger methods execute without throwing")
    func loggerMethodsDoNotThrow() {
        let logger = DefaultChartLogger()
        // These should silently succeed (no-op implementation)
        logger.debug("test debug")
        logger.info("test info")
        logger.warning("test warning")
        logger.error("test error")
        // If we get here without crashing, test passes
    }
}
