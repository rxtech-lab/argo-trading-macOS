# XCUITest Plan: ArgoTradingSwift Document App

## Overview

This document describes a detailed end-to-end UI test plan for the ArgoTradingSwift macOS document
app using the XCUITest framework. Tests live in the `ArgoTradingSwiftUITests` target and operate on
a real (or simulated) `.rxtrading` document. Because this is a document-based app, every test suite
must first create or open a project document before interacting with any feature under test.

All XCUITest code belongs to `ArgoTradingSwiftUITests/` and accesses the app through
`XCUIApplication()`. Accessibility identifiers must be added to views that do not yet expose them;
the plan notes where identifiers are required.

---

## Prerequisites & Setup

### Test Project Fixture

A minimal pre-built `.rxtrading` project bundle should be committed to the test resources folder
(`ArgoTradingSwiftUITests/Resources/TestProject.rxtrading`). This bundle contains:

- A valid `dataFolder/` path (can be empty initially).
- A valid `strategyFolder/` containing at least one pre-compiled `.wasm` strategy file.
- A valid `resultFolder/` (empty initially).

### Required Accessibility Identifiers

Before implementing any tests, the following `accessibilityIdentifier` values must be added to the
corresponding SwiftUI views:

| View / Control | Identifier |
|---|---|
| New project "Create" button (`NewDocumentFirstScreen`) | `"welcome.createNew"` |
| Open existing project button (`NewDocumentFirstScreen`) | `"welcome.openExisting"` |
| Recent project row (`RecentProjectsPanel`) | `"recentProject.<url-hash>"` |
| Sidebar mode picker — Backtest segment | `"sidebar.mode.backtest"` |
| Sidebar mode picker — Trading segment | `"sidebar.mode.trading"` |
| Backtest tab picker — General tab | `"backtestTab.general"` |
| Backtest tab picker — Results tab | `"backtestTab.results"` |
| Sidebar data file row (`ParquetFileRow`) | `"sidebar.dataFile.<filename>"` |
| Sidebar strategy file row (`StrategyFileRow`) | `"sidebar.strategyFile.<filename>"` |
| Sidebar result file row (`ResultFileRow`) | `"sidebar.resultFile.<filename>"` |
| Dataset download menu item / toolbar button | `"toolbar.downloadDataset"` |
| Download provider picker | `"download.providerPicker"` |
| Download button (confirmation action) | `"download.button"` |
| Download cancel / stop button | `"download.stopButton"` |
| Download progress view | `"download.progressView"` |
| Chart view (`LightweightChartView`) | `"chart.priceChart"` |
| Chart time-interval picker | `"chart.intervalPicker"` |
| Chart "Showing N of M records" label | `"chart.recordCountLabel"` |
| Schema picker button (`ToolbarRunningSectionView`) | `"toolbar.schemaPicker"` |
| Dataset picker button (`ToolbarRunningSectionView`) | `"toolbar.datasetPicker"` |
| Run / Play button (toolbar) | `"toolbar.runButton"` |
| Toolbar status label | `"toolbar.statusLabel"` |
| Result detail segment control | `"result.tabPicker"` |
| Trades table (`TradesTableView`) | `"result.tradesTable"` |
| Marks table (`MarksTableView`) | `"result.marksTable"` |
| Orders table (`OrdersTableView`) | `"result.ordersTable"` |
| Surrounding price-data sheet | `"surroundingPrice.sheet"` |
| Trading provider picker button | `"toolbar.tradingProviderPicker"` |
| Start live trading button | `"toolbar.startLiveButton"` |
| Stop live trading button | `"toolbar.stopLiveButton"` |
| Live chart view (`LiveChartView`) | `"chart.liveChart"` |
| Toolbar status — trading indicator | `"toolbar.status.trading"` |

---

## Test Suite 1: Dataset Download

**Goal:** Verify that a user can open the dataset-download sheet, configure a provider, trigger a
download, observe progress, and confirm the new Parquet file appears in the sidebar.

### Pre-conditions

- App is launched with the fixture document open.
- No Parquet files exist in `dataFolder/` at the start of the test.
- A valid Polygon.io API key is injected via a launch argument
  (`-PolygonApiKey <key>`) so the keychain authentication dialog is bypassed.

### Test Cases

#### TC-DS-01 — Open dataset-download sheet

1. Right-click the sidebar or press the `toolbar.downloadDataset` button.
2. Assert: the download sheet is presented and shows the configuration title "Download Dataset"
   (not the in-progress title "Downloading Dataset").
3. Assert: the provider picker form section is visible.

#### TC-DS-02 — Provider picker shows available providers

1. In the open download sheet tap the `download.providerPicker`.
2. Assert: at least one provider option (e.g., "polygon") is listed.

#### TC-DS-03 — Provider configuration form appears after selecting a provider

1. Select a provider from `download.providerPicker`.
2. Assert: the "Provider Configuration" section appears with at least one form field.

#### TC-DS-04 — Download triggers progress view

1. Fill in the provider configuration form (credentials are pre-populated via
   `launchEnvironment["POLYGON_API_KEY"]` in the test setup).
2. Tap `download.button`.
3. Assert: `download.progressView` becomes visible.
4. Assert: toolbar status transitions to `.downloading`.

#### TC-DS-05 — Stop button cancels an in-progress download

1. While `download.progressView` is visible, tap `download.stopButton`.
2. Assert: `download.progressView` disappears.
3. Assert: toolbar status label shows "Cancelled".

#### TC-DS-06 — Successful download adds file to sidebar

1. Perform a full download (use a short date range and a mocked server response in CI, or a
   sandboxed test provider that writes a fixture Parquet file).
2. Assert: the download sheet is dismissed.
3. Assert: toolbar status shows "Downloaded".
4. Assert: a new `sidebar.dataFile.<filename>` row is visible in the sidebar data section.

#### TC-DS-07 — Error during download shows alert

1. Provide an invalid API key and tap `download.button`.
2. Assert: an alert with an error message is presented.
3. Assert: toolbar status shows "Failed".

---

## Test Suite 2: Chart Scrolling and Infinite Data Loading

**Goal:** Verify that the price chart loads data incrementally as the user scrolls, respects
boundaries, and correctly updates the "Showing N of M records" label.

### Pre-conditions

- Fixture document has a pre-seeded Parquet file with at least 2,000 price records.
- The sidebar data file row is selected so `ChartContentView` is visible.
- The chart is in the default (most-recent data) position.

### Test Cases

#### TC-CH-01 — Chart initializes with data

1. Select a Parquet file row in the sidebar (`sidebar.dataFile.<filename>`).
2. Switch to the chart view (tap chart toolbar button with identifier `"toolbar.showChart"`).
3. Assert: `chart.priceChart` is visible.
4. Assert: `chart.recordCountLabel` text matches the pattern `"Showing \d+ of \d+ records"` and
   `N < M` (initial window is smaller than total).

#### TC-CH-02 — Scrolling left (older data) loads more records

1. Read the current "Showing N of M records" count `N₀` from `chart.recordCountLabel`.
2. Perform a slow scroll gesture from the right edge to the left edge of `chart.priceChart`
   (simulating scrolling backward in time).
3. Wait up to 3 seconds for the label to update.
4. Assert: the new count `N₁ > N₀` (additional data was loaded from the beginning).

#### TC-CH-03 — Scrolling to the beginning stops loading (no infinite loop)

1. Perform repeated leftward scroll gestures (at least 10 full-width swipes) on `chart.priceChart`
   until `chart.recordCountLabel` shows `"Showing M of M"` or the count stops increasing across
   two consecutive scroll-and-wait cycles (wait 2 seconds between each cycle).
2. Assert: no spinner or loading indicator remains visible after a 2-second pause.
3. Assert: the count equals the total (`N == M`).

#### TC-CH-04 — Scroll position is preserved after data load

1. Scroll to approximately the middle of the dataset.
2. Note the first visible candle date from the legend.
3. Trigger a data load by scrolling slightly further left.
4. Assert: after the load completes, the chart is _not_ reset to the most-recent position; the
   previously visible area is still centered.

#### TC-CH-05 — Time-interval change reloads data

1. With the chart displaying data, tap `chart.intervalPicker` and select a different interval
   (e.g., from 1s to 1m).
2. Assert: a loading indicator appears briefly.
3. Assert: `chart.recordCountLabel` updates to reflect the aggregated count.

#### TC-CH-06 — Pinch-to-zoom adjusts visible window

1. Perform a magnification gesture on `chart.priceChart` (scale = 2.0).
2. Assert: `chart.recordCountLabel` reflects a narrower visible window (lower N, same M).
3. Perform the inverse pinch (scale = 0.5).
4. Assert: the visible window widens.

---

## Test Suite 3: Run Strategy (Backtest)

**Goal:** Verify the full backtest workflow: selecting a schema/strategy, selecting a dataset,
triggering the run, observing progress, and confirming a result file is created.

### Pre-conditions

- Fixture document contains a `.wasm` strategy in `strategyFolder/`.
- A Parquet file is present in `dataFolder/`.
- A schema that references the strategy file is pre-configured in the document.

### Test Cases

#### TC-BT-01 — Schema picker lists available schemas

1. Tap `toolbar.schemaPicker`.
2. Assert: a popover appears listing at least one schema.
3. Dismiss the popover.

#### TC-BT-02 — Dataset picker lists available Parquet files

1. Tap `toolbar.datasetPicker`.
2. Assert: a popover appears listing at least one dataset file name.
3. Select the test Parquet file.
4. Assert: `toolbar.datasetPicker` label updates to reflect the selected file.

#### TC-BT-03 — Run button is disabled without schema

1. Ensure no schema is selected (or the selected schema has an empty `strategyPath`).
2. Assert: the schema picker button label is rendered in red (error style), indicating a missing
   strategy.
3. Assert: `toolbar.runButton` is disabled (`.isEnabled == false`).

#### TC-BT-04 — Run button triggers backtest

1. Select a valid schema (`toolbar.schemaPicker`).
2. Select a dataset (`toolbar.datasetPicker`).
3. Tap `toolbar.runButton`.
4. Assert: `toolbar.statusLabel` transitions to the backtesting state (shows progress counter
   e.g., "Backtesting 1/5").
5. Assert: the run button is disabled or changes to a "Stop" button during execution.

#### TC-BT-05 — Backtest progress updates incrementally

1. Start a backtest (TC-BT-04).
2. Observe `toolbar.statusLabel` at 0.5-second intervals.
3. Assert: the current/total counter in the label increments at least once before completion.

#### TC-BT-06 — Successful backtest creates result in sidebar

1. Wait for `toolbar.statusLabel` to show "Finished" or a checkmark state (timeout: 60 seconds).
2. Tap `backtestTab.results` in the sidebar.
3. Assert: at least one `sidebar.resultFile.<filename>` row is visible.

#### TC-BT-07 — Selecting a result file opens BacktestResultDetailView

1. After a successful backtest, tap a result file row in the sidebar.
2. Assert: the detail area shows the general tab form with "Symbol", "Profit & Loss" sections.

#### TC-BT-08 — Running multiple backtests accumulates results

1. Run the same strategy twice in sequence.
2. Assert: two separate result rows appear in the sidebar, each with a distinct timestamp.

---

## Test Suite 4: Click to Navigate to Signal and Trade Data Points

**Goal:** Verify that selecting a row in the Trades or Marks table scrolls the corresponding chart
to the correct timestamp, and that the "View Surrounding Price Data" context-menu action opens a
price detail sheet.

### Pre-conditions

- A backtest result is already present in `resultFolder/` (can be pre-seeded in the fixture).
- The result is selected in the sidebar and `BacktestResultDetailView` is visible.

### Test Cases

#### TC-NAV-01 — Selecting a trade row scrolls chart to that timestamp

1. Tap `result.tabPicker` and select the "Trades" tab.
2. Note the timestamp of the first row in `result.tradesTable`.
3. Tap the first row to select it.
4. In the sidebar, tap `backtestTab.general` and then select the data file row
   (`sidebar.dataFile.<filename>`) that corresponds to this result's `dataFilePath` to open
   `ChartContentView`.
5. Assert: `chart.priceChart` is scrolled so that the noted timestamp is visible — verify by
   reading the `chart.recordCountLabel` or the chart legend (which shows OHLCV for the hovered
   candle at the scrolled-to position).

#### TC-NAV-02 — Selecting a mark row scrolls chart to signal time

1. Tap `result.tabPicker` and select the "Marks" tab.
2. Note the signal time of the first row in `result.marksTable`.
3. Tap the first row.
4. Navigate to the data chart view.
5. Assert: chart legend shows the noted signal date.

#### TC-NAV-03 — Context menu "View Surrounding Price Data" on a trade row

1. In the Trades tab, right-click the first row in `result.tradesTable`.
2. Assert: a context menu appears with "View Surrounding Price Data".
3. Tap "View Surrounding Price Data".
4. Assert: `surroundingPrice.sheet` sheet is presented.
5. Assert: the sheet title contains the trade's symbol and side (e.g., "AAPL - Buy").
6. Assert: at least one price row is visible in the sheet's table.
7. Dismiss the sheet.

#### TC-NAV-04 — Context menu "View Surrounding Price Data" on a mark row

1. In the Marks tab, right-click the first row in `result.marksTable`.
2. Tap "View Surrounding Price Data".
3. Assert: `surroundingPrice.sheet` is presented with the mark title and category.
4. Dismiss the sheet.

#### TC-NAV-05 — Pagination in trades table

1. In the Trades tab, verify that the footer shows `"Page 1"` and a total trade count.
2. If `hasMore` is true, tap the `">"` (next page) button.
3. Assert: `"Page 2"` is shown in the footer.
4. Tap the `"<"` (previous page) button.
5. Assert: `"Page 1"` is shown and the first page rows are restored.

#### TC-NAV-06 — Pagination in marks table

Repeat TC-NAV-05 for the Marks tab (`result.marksTable`).

#### TC-NAV-07 — Strategy name link navigates to strategy detail

1. In the General tab of `BacktestResultDetailView`, tap the strategy name link (blue, `.link`
   button style).
2. Assert: the sidebar selection changes to the corresponding strategy file row.
3. Assert: `StrategyDetailView` is visible showing the strategy metadata.

---

## Test Suite 5: Live Trading

**Goal:** Verify the live trading workflow: switching to Trading mode, selecting a provider,
starting a session, observing live chart updates, and stopping the session.

### Pre-conditions

- A trading provider is configured in the document (via `ManageTradingProvidersView`).  For CI, use
  a paper/sandbox provider or a mock provider whose keys are injected as launch arguments.
- The fixture document has a strategy configured in its selected schema.

### Test Cases

#### TC-LT-01 — Switch to Trading mode

1. Tap `sidebar.mode.trading` in the mode picker.
2. Assert: the sidebar switches to the trading sidebar layout (`TradingSideBar`).
3. Assert: `toolbar.tradingProviderPicker` button is visible in the toolbar.

#### TC-LT-02 — Trading provider picker lists providers

1. Tap `toolbar.tradingProviderPicker`.
2. Assert: a popover appears listing at least one configured provider.
3. Select a provider.
4. Assert: the button label updates to the provider name.

#### TC-LT-03 — Start live trading

1. Select a schema and trading provider.
2. Tap `toolbar.startLiveButton`.
3. Assert: a new session row appears in the trading sidebar.
4. Assert: `toolbar.status.trading` indicator becomes visible (green dot).
5. Assert: `toolbar.startLiveButton` changes to `toolbar.stopLiveButton` (or is disabled).

#### TC-LT-04 — Live chart is displayed for the active session

1. With a running session, tap the session row in the sidebar.
2. Assert: `chart.liveChart` is visible.
3. Assert: the chart shows at least one candle (the live data aggregator has produced a bar).

#### TC-LT-05 — Live chart updates as new data arrives

1. With `chart.liveChart` visible and trading running, wait 5 seconds.
2. Capture the current candle count from the chart.
3. Wait another 5 seconds.
4. Assert: the candle count has increased (new live data bars were appended).

#### TC-LT-06 — Interval selector works on the live chart

1. Tap `chart.intervalPicker` and select a coarser interval (e.g., 1-minute).
2. Assert: the chart re-renders without an error alert.
3. Assert: the label or candle density reflects the coarser aggregation.

#### TC-LT-07 — Stop live trading

1. Tap `toolbar.stopLiveButton`.
2. Assert: `toolbar.status.trading` green dot disappears.
3. Assert: `toolbar.startLiveButton` becomes available again.

#### TC-LT-08 — Historical data is displayed after stopping

1. After stopping the session (TC-LT-07), wait 2 seconds (reload delay).
2. Assert: `chart.liveChart` still shows data (historical Parquet data loaded from file).
3. Assert: trade/mark markers from the completed session are visible on the chart.

#### TC-LT-09 — Multiple sessions are listed in the sidebar

1. Start and stop two separate trading sessions.
2. Assert: two distinct session rows appear in the trading sidebar.
3. Assert: selecting each row navigates to its own `LiveChartView` with the correct `runURL`.

#### TC-LT-10 — "No Run Selected" empty state

1. In Trading mode with no session selected (or after deselecting), assert that the main content
   area shows `"No Run Selected"` with the empty-state icon.

---

## Test Infrastructure & CI Notes

### Launch Arguments

Pass the following `XCUIApplication.launchArguments` to control the app during tests:

| Argument | Purpose |
|---|---|
| `-UITestMode 1` | Disables keychain biometric prompts; uses mock authentication. |
| `-UseFixtureDocument 1` | Opens the fixture `.rxtrading` document automatically on launch. |
| `-MockTradingProvider 1` | Replaces live provider calls with a deterministic mock. |

> **Security note:** API keys and other credentials must **not** be passed as launch arguments
> (they appear in process listings and CI logs). Instead, supply them via
> `launchEnvironment["POLYGON_API_KEY"]` or by pre-seeding a temporary Keychain entry inside the
> test's `setUp()` method. Remove the entry in `tearDown()`.

### Fixture Document Path

The fixture document path should be passed via `launchEnvironment["FIXTURE_DOCUMENT_PATH"]` so the
app's `Scene` can open it during `application(_:didFinishLaunchingWithOptions:)`.

### Async Waiting

Use `XCTNSPredicateExpectation` with a generous timeout (default 30 seconds, up to 120 seconds for
download/backtest operations) rather than `sleep()` to avoid flakiness.

### Test Isolation

Each test case must:
1. Launch a fresh `XCUIApplication` instance (`app.launch()`).
2. Open the fixture document (or a freshly copied temp clone of it).
3. Tear down by calling `app.terminate()` and deleting any files written to the temp fixture clone.

### Organizing the Test Files

```
ArgoTradingSwiftUITests/
├── Resources/
│   └── TestProject.rxtrading/          # Fixture document bundle
│       ├── dataFolder/                  # Pre-seeded Parquet files
│       ├── strategyFolder/              # Pre-compiled .wasm strategy
│       └── resultFolder/               # Pre-seeded backtest result
├── Helpers/
│   ├── XCUIApplication+Launch.swift    # App launch helpers with arguments
│   ├── XCUIElement+Wait.swift          # waitForExistence / waitForValue helpers
│   └── FixtureManager.swift            # Copies fixture to temp dir, cleans up
├── DatasetDownloadUITests.swift         # Suite 1
├── ChartScrollUITests.swift             # Suite 2
├── RunStrategyUITests.swift             # Suite 3
├── NavigationUITests.swift              # Suite 4
└── LiveTradingUITests.swift             # Suite 5
```
