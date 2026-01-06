# LightweightChart

A Swift package that provides a wrapper around TradingView's Lightweight Charts library for macOS applications.

## Requirements

- macOS 15.0+
- Swift 6.0+
- Xcode 16.0+ (for building)

> **Note**: This package requires macOS with SwiftUI and WebKit frameworks. It cannot be built or tested on Linux.

## Features

- TradingView Lightweight Charts integration via WKWebView
- Support for candlestick and line charts
- Technical indicators (SMA, EMA, VWAP, RSI, MACD)
- Chart markers for trades and signals
- Native SwiftUI tooltip views
- Configurable chart options

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../packages/lightweight-chart")
]
```

Or add it via Xcode's package manager by pointing to the local package directory.

## Usage

### Basic Setup

```swift
import LightweightChart
import SwiftUI

struct ContentView: View {
    @State private var chartService = LightweightChartService()
    @State private var priceData: [PriceData] = []

    var body: some View {
        LightweightChartView(
            data: priceData,
            chartType: .candlestick,
            isLoading: false,
            totalDataCount: priceData.count
        )
        .environment(chartService)
    }
}
```

The `LightweightChartView` accepts `PriceData` and automatically converts it to the appropriate JavaScript format based on the selected `chartType`.

### Chart Types

The package provides these main types:

- `LightweightChartService` - Observable service that manages the chart WebView
- `LightweightChartView` - SwiftUI view wrapper for the chart
- `ChartMarkerTooltip` - Native tooltip view for marker information
- `ChartType` - Enum for chart type (`.line`, `.candlestick`)
- `PriceData` - Primary data structure for OHLCV price data
- `MarkerDataJS` - Data structure for chart markers
- `IndicatorSettings` / `IndicatorConfig` - Configuration for technical indicators

### Custom Logger

You can provide your own logger by conforming to the `ChartLogger` protocol:

```swift
struct MyLogger: ChartLogger {
    func debug(_ message: String) { print("DEBUG: \(message)") }
    func info(_ message: String) { print("INFO: \(message)") }
    func warning(_ message: String) { print("WARNING: \(message)") }
    func error(_ message: String) { print("ERROR: \(message)") }
}

let service = LightweightChartService(logger: MyLogger())
```

## Building and Testing

The package includes a Makefile for common operations:

```bash
# Build the package (macOS only)
make build

# Run tests (macOS only)
make test

# Clean build artifacts
make clean
```

## License

This package is part of the ArgoTrading project.
