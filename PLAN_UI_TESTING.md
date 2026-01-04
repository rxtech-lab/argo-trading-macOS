# UI Testing Plan for ArgoTradingSwift

## Overview

This plan outlines a comprehensive UI testing strategy using real DuckDB data and a real WASM strategy file. The testing will leverage the existing Swift Testing framework and ViewInspector library already in place.

---

## Prerequisites & Test Fixtures

### 1. Test Data Files (to be added to repository)

```
ArgoTradingSwiftTests/
└── Fixtures/
    ├── TestData/
    │   └── ETHUSDT_2025-01-01_2025-01-07_1_minute.parquet  # Real price data
    ├── Strategies/
    │   └── simple_strategy.wasm                            # User-provided WASM
    └── Results/
        ├── trades.parquet                                  # Pre-generated backtest results
        └── marks.parquet                                   # Pre-generated marks data
```

### 2. Test Document Template

Create a pre-configured `ArgoTradingDocument` fixture with:
- `dataFolder` pointing to `Fixtures/TestData/`
- `strategyFolder` pointing to `Fixtures/Strategies/`
- `resultFolder` pointing to `Fixtures/Results/`
- Pre-defined schema referencing `simple_strategy.wasm`

---

## Test Categories

### Category 1: Strategy Execution Tests

**Location:** `ArgoTradingSwiftUITests/BacktestExecutionTests.swift`

| Test Case | Description | Approach |
|-----------|-------------|----------|
| `testRunStrategyWithRealWASM` | Execute strategy and verify completion | Use `BacktestService` with real WASM, assert `onBacktestEnd()` called |
| `testRunStrategyProgressUpdates` | Verify progress callbacks fire | Mock `ToolbarStatusService`, verify progress updates |
| `testRunStrategyGeneratesResults` | Check results files created | Run backtest, verify trades.parquet and marks.parquet exist |
| `testRunStrategyWithInvalidWASM` | Error handling for corrupt WASM | Use corrupted file, verify error state |

**Implementation Notes:**
- Create temporary directories using `FileManager.default.temporaryDirectory`
- Copy fixture files to temp location before each test
- Use `async/await` with timeouts for backtest completion
- Assert on `BacktestService.isRunning` state transitions

---

### Category 2: Chart Scrolling & Rendering Tests

**Location:** `ArgoTradingSwiftUITests/ChartScrollingTests.swift`

| Test Case | Description | Approach |
|-----------|-------------|----------|
| `testChartLoadsInitialData` | Chart displays data on open | Load parquet, verify `priceData` array populated |
| `testScrollLeftLoadsMoreData` | Scrolling left triggers load | Simulate scroll, verify `loadMoreAtBeginning()` called |
| `testScrollRightLoadsMoreData` | Scrolling right triggers load | Simulate scroll, verify `loadMoreAtEnd()` called |
| `testChartTimeIntervalSwitch` | Changing interval reloads data | Switch to 5min, verify aggregated data loaded |
| `testChartTypeSwitch` | Switch between candlestick/line | Toggle type, verify JS message sent |

**Implementation Notes:**
- Use `PriceChartViewModel` directly (already well-tested)
- Mock `DuckDBService` for unit tests, use real service for integration
- Verify scroll guard prevents cascade loading (500ms delay)

#### Visual Regression Testing (Sub-section)

**Approach Options:**

**Option A: Snapshot Testing with `swift-snapshot-testing`**
```swift
// Add dependency: pointfreeco/swift-snapshot-testing

func testChartRenderingSnapshot() async {
    let chartView = LightweightChartView(...)
    assertSnapshot(matching: chartView, as: .image)
}
```

**Option B: Custom Screenshot Comparison**
```swift
// Capture WKWebView as image after render
func captureChartScreenshot() -> NSImage {
    let config = WKSnapshotConfiguration()
    return await webView.takeSnapshot(configuration: config)
}

// Compare with baseline
func testChartVisualRegression() async {
    let screenshot = await captureChartScreenshot()
    let baseline = loadBaselineImage("chart_baseline.png")
    XCTAssertEqual(screenshot.pixelData, baseline.pixelData, tolerance: 0.01)
}
```

**Option C: Percy/Chromatic Integration (CI-based)**
- Export chart HTML to temp file
- Use headless browser to capture screenshot
- Upload to Percy for diff analysis

**Recommended:** Option A (swift-snapshot-testing) for local development, Option C for CI/CD pipeline.

---

### Category 3: Marker Rendering Tests

**Location:** `ArgoTradingSwiftUITests/MarkerRenderingTests.swift`

| Test Case | Description | Approach |
|-----------|-------------|----------|
| `testTradeMarkersRendered` | BUY/SELL markers appear on chart | Load trades.parquet, verify `TradeOverlay` array populated |
| `testSignalMarkersRendered` | Signal marks appear on chart | Load marks.parquet, verify `MarkOverlay` array populated |
| `testMarkerPositioning` | Markers align with correct candles | Compare marker timestamps with price data |
| `testMarkerColors` | BUY=green, SELL=red | Assert marker color properties |
| `testMarkerShapes` | Correct shapes per signal type | Verify shape matches signal category |

**Implementation Notes:**
- Use `BacktestResultService` to load pre-generated results
- Test `ChartMarkerTooltip` component in isolation with ViewInspector
- Verify JavaScript `addTradeMarkers()` and `addMarkMarkers()` calls

---

### Category 4: Marker Interaction Tests

**Location:** `ArgoTradingSwiftUITests/MarkerInteractionTests.swift`

| Test Case | Description | Approach |
|-----------|-------------|----------|
| `testMarkerHoverShowsTooltip` | Hovering marker shows tooltip | Simulate `markerHover` JS message, verify tooltip visible |
| `testMarkerClickScrollsChart` | Clicking marker scrolls to trade | Trigger click, verify `ChartScrollRequest` dispatched |
| `testTradeRowClickScrollsToMarker` | Click trade in table scrolls chart | Click table row, verify chart scrolled to timestamp |
| `testMarkerRowClickScrollsToMarker` | Click mark in table scrolls chart | Click table row, verify chart scrolled to timestamp |
| `testTooltipDisplaysTradeInfo` | Tooltip shows PnL, qty, price | Inspect `TradeMarkerSection` content |
| `testTooltipDisplaysMarkInfo` | Tooltip shows signal info | Inspect `MarkMarkerSection` content |
| `testTooltipPositioning` | Tooltip stays within bounds | Simulate edge positions, verify no overflow |

**Implementation Notes:**
- Mock JavaScript bridge for marker hover events
- Use `ChartScrollRequest` publisher to verify scroll requests
- Test `JSMarkerHoverData` parsing from JavaScript messages

**Interaction Flow to Test:**
```
1. User clicks row in TradesTableView
   → TradesTableView.onTapGesture triggers
   → NavigationService.scrollToTimestamp published
   → BacktestChartView receives scroll request
   → PriceChartViewModel.scrollToTimestamp called
   → Chart scrolls + marker highlighted
```

---

### Category 5: Import Strategy Tests

**Location:** `ArgoTradingSwiftUITests/StrategyImportTests.swift`

| Test Case | Description | Approach |
|-----------|-------------|----------|
| `testImportWASMFile` | Import copies file to strategy folder | Call `importStrategy()`, verify file exists |
| `testImportUpdatesFileList` | Sidebar shows new strategy | Import, verify `strategyFiles` array updated |
| `testImportDuplicateHandling` | Duplicate names handled | Import same file twice, verify naming |
| `testImportInvalidFile` | Non-WASM rejected | Try importing .txt, verify error |
| `testDeleteStrategy` | Remove strategy from folder | Delete, verify file removed and list updated |
| `testRenameStrategy` | Rename updates references | Rename, verify schema paths updated |
| `testImportViaFileDialog` | Full UI flow test | Use XCUITest to open panel and select file |

**Implementation Notes:**
- `StrategyService` already has good test coverage (see `StrategyServiceTests.swift`)
- Add integration tests with real file system operations
- Test `FolderMonitor` callback triggers

---

## Test Infrastructure Setup

### 1. XCUITest Configuration

```swift
// ArgoTradingSwiftUITests/UITestCase.swift

class UITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Set launch arguments to use test fixtures
        app.launchArguments = [
            "--uitesting",
            "--fixtures-path", fixturesPath
        ]
        app.launch()
    }

    var fixturesPath: String {
        Bundle(for: type(of: self))
            .path(forResource: "Fixtures", ofType: nil)!
    }
}
```

### 2. Test Document Initialization

```swift
// Modify ArgoTradingSwiftApp.swift to support test mode
@main
struct ArgoTradingSwiftApp: App {
    init() {
        if CommandLine.arguments.contains("--uitesting") {
            setupTestEnvironment()
        }
    }

    private func setupTestEnvironment() {
        // Load test fixtures
        // Configure services with test data paths
    }
}
```

### 3. Mock Service Layer for Unit Tests

```swift
// Already exists: MockDuckDBService
// Add:
// - MockBacktestService (simulates WASM execution)
// - MockLightweightChartService (captures JS calls)
// - MockStrategyService (for file operations)
```

---

## Visual Regression Test Setup

### Recommended: swift-snapshot-testing Integration

**1. Add Package Dependency:**
```swift
// Package.swift or Xcode SPM
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
```

**2. Create Chart Snapshot Tests:**
```swift
// ArgoTradingSwiftTests/ChartSnapshotTests.swift

import SnapshotTesting
import XCTest

final class ChartSnapshotTests: XCTestCase {

    func testCandlestickChartAppearance() async throws {
        // Setup chart with known data
        let viewModel = PriceChartViewModel(duckDBService: realDuckDBService)
        await viewModel.loadData(from: fixtureParquetPath)

        let chartView = LightweightChartView(
            priceData: viewModel.priceData,
            // ... other params
        )

        // Capture and compare
        assertSnapshot(matching: chartView, as: .image(size: CGSize(width: 800, height: 600)))
    }

    func testChartWithTradeMarkers() async throws {
        // Load chart with overlay data
        let chartView = BacktestChartView(...)
        assertSnapshot(matching: chartView, as: .image)
    }
}
```

**3. Baseline Management:**
- Store baseline images in `__Snapshots__/` directory (auto-created)
- Commit baselines to git for CI comparison
- Use `record: true` to update baselines when intentional changes made

---

## Test Execution Plan

### Phase 1: Unit Tests (No UI, Fast)
- `PriceChartViewModel` tests (existing + extensions)
- `StrategyService` tests (existing + extensions)
- Model validation tests
- Service protocol mock tests

### Phase 2: Integration Tests (Real Services)
- DuckDB with real Parquet files
- BacktestService with real WASM
- File system operations with temp directories

### Phase 3: UI Component Tests (ViewInspector)
- `ChartMarkerTooltip` rendering
- `TradesTableView` row interaction
- `StrategyDetailView` import button

### Phase 4: End-to-End UI Tests (XCUITest)
- Full backtest workflow
- Import strategy via file dialog
- Click marker → chart scroll flow

### Phase 5: Visual Regression (Snapshot)
- Chart appearance baselines
- Marker rendering baselines
- Tooltip positioning baselines

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/ui-tests.yml
name: UI Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project ArgoTradingSwift.xcodeproj \
            -scheme ArgoTradingSwift \
            -destination 'platform=macOS'

      - name: Run UI Tests
        run: |
          xcodebuild test \
            -project ArgoTradingSwift.xcodeproj \
            -scheme ArgoTradingSwiftUITests \
            -destination 'platform=macOS'

      - name: Upload Snapshot Failures
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-failures
          path: '**/Failures/*.png'
```

---

## File Structure After Implementation

```
ArgoTradingSwiftTests/
├── Fixtures/
│   ├── TestData/
│   │   └── ETHUSDT_2025-01-01_2025-01-07_1_minute.parquet
│   ├── Strategies/
│   │   └── simple_strategy.wasm
│   └── Results/
│       ├── trades.parquet
│       └── marks.parquet
├── Mocks/
│   ├── MockDuckDBService.swift (existing)
│   ├── MockBacktestService.swift
│   ├── MockLightweightChartService.swift
│   └── MockStrategyService.swift
├── Snapshots/
│   └── __Snapshots__/
│       ├── ChartSnapshotTests/
│       │   ├── testCandlestickChartAppearance.png
│       │   └── testChartWithTradeMarkers.png
│       └── ...
├── ChartScrollingTests.swift
├── MarkerRenderingTests.swift
├── MarkerInteractionTests.swift
├── BacktestExecutionTests.swift
└── ChartSnapshotTests.swift

ArgoTradingSwiftUITests/
├── UITestCase.swift (base class)
├── BacktestWorkflowUITests.swift
├── StrategyImportUITests.swift
└── ChartInteractionUITests.swift
```

---

## Summary

| Requirement | Test Approach | Key Files |
|-------------|---------------|-----------|
| 1. Running strategy | Integration test with real WASM | `BacktestExecutionTests.swift` |
| 2. Chart scrolling & rendering | ViewModel tests + snapshots | `ChartScrollingTests.swift`, `ChartSnapshotTests.swift` |
| 3. Marker rendering | Load results, verify overlays | `MarkerRenderingTests.swift` |
| 4. Marker/trade click → scroll | Mock JS bridge, verify scroll request | `MarkerInteractionTests.swift` |
| 5. Import strategy | File system integration tests | `StrategyImportTests.swift` |

**Estimated New Test Files:** 8-10 files
**Estimated New Test Cases:** 40-50 cases
**Dependencies to Add:** `swift-snapshot-testing`
