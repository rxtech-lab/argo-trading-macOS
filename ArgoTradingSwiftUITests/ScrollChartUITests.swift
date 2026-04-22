//
//  ScrollChartUITests.swift
//  ArgoTradingSwiftUITests
//
//  End-to-end regression guard for commit 7731bb1 ("fix: scrolling not loading
//  on large dataset"). Opens a project backed by ~675k rows of 1-minute bars,
//  pans the price chart left, and asserts that `loadMoreAtBeginning` actually
//  fired by watching the on-screen record counter grow past the initial buffer.
//

import XCTest

final class ScrollChartUITests: XCTestCase {
    private static let largeDatasetLabel = "BTCUSDT, •, 1 minute, Jan 1, 2025 - Apr 20, 2026"
    private static let smallDatasetLabel = "BTCUSDT, •, 1 minute, Apr 18, 2026 - Apr 19, 2026"
    private static let largeDatasetRelativePath = "data/BTCUSDT_2025-01-01_2026-04-20_1_minute.parquet"

    /// Baseline: open the project whose `selectedDatasetURL` is already the
    /// large parquet, click it, scroll, expect more rows to load.
    func testChartLoadsMoreBarsWhenScrollingLeft() throws {
        let projectURL = try requireLargeDatasetFixture(projectName: "Scroll test project")
        let app = launch(projectURL: projectURL)

        let dataset = app.buttons[Self.largeDatasetLabel].firstMatch
        XCTAssertTrue(
            dataset.waitForExistence(timeout: 20),
            "Dataset row '\(Self.largeDatasetLabel)' not found in sidebar"
        )
        dataset.click()

        scrollChartAndExpectLoadMore(app: app)
    }

    /// Regression: open a *different* project first (whose selected dataset is
    /// the small parquet), then switch to the large parquet via the sidebar and
    /// scroll. Guards against the chart/view-model retaining stale state from
    /// the previously-selected dataset and failing to wire up load-more.
    func testChartLoadsMoreBarsAfterSwitchingFromSmallDataset() throws {
        // "Test project" preselects the tiny 2-day parquet. Both projects
        // share testdata/data/, so the large parquet still shows up in the
        // sidebar and we can click it to switch.
        let projectURL = try requireLargeDatasetFixture(projectName: "Scroll test project")
        let app = launch(projectURL: projectURL)

        let smallDataset = app.buttons[Self.smallDatasetLabel].firstMatch
        XCTAssertTrue(
            smallDataset.waitForExistence(timeout: 20),
            "Small dataset row '\(Self.smallDatasetLabel)' not found in sidebar"
        )
        smallDataset.click()
        // wait the dataset is loaded
        XCTAssertTrue(app/*@START_MENU_TOKEN@*/ .staticTexts["Price Chart"]/*[[".groups.staticTexts[\"Price Chart\"]",".staticTexts[\"Price Chart\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .waitForExistence(timeout: 20), "Price Chart not found after clicking fixture — it may take a while to load")

        let largeDataset = app.buttons[Self.largeDatasetLabel].firstMatch
        XCTAssertTrue(
            largeDataset.waitForExistence(timeout: 20),
            "Large dataset row '\(Self.largeDatasetLabel)' not found in sidebar"
        )
        largeDataset.click()

        scrollChartAndExpectLoadMore(app: app)
    }

    // MARK: - Shared flow

    /// Verifies that once the Price Chart is (or becomes) visible for the large
    /// parquet, panning left causes `loadMoreAtBeginning` to fire and grow the
    /// on-screen record counter past the initial 500-row buffer.
    private func scrollChartAndExpectLoadMore(
        app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.staticTexts["Price Chart"].waitForExistence(timeout: 30),
            "Price Chart header did not appear after opening dataset",
            file: file, line: line
        )

        // The counter may take a moment to populate while DuckDB runs the
        // COUNT(*) on the parquet file.
        let counter = app.staticTexts["argo.priceChart.recordCount"]
        XCTAssertTrue(
            counter.waitForExistence(timeout: 30),
            "Record-count label missing — accessibility id wired up?",
            file: file, line: line
        )

        // Wait for the initial load (bufferSize=500) to finish populating.
        // Use NSPredicate + XCTWaiter rather than a tight polling loop:
        // every `counter.label` access pulls a full accessibility snapshot
        // that walks through the SwiftUI WebView, and on macOS 26 doing that
        // aggressively while the WebView is mid-update can trip an
        // EXC_BREAKPOINT in `_WebKit_SwiftUI`.
        Self.waitForNonZeroLoaded(counter, timeout: 30)
        let initial = UITestUtils.readRecordCount(counter)
        XCTAssertEqual(
            initial.loaded, 500,
            "Initial buffer should equal PriceChartViewModel.bufferSize=500 (got \(initial.loaded))",
            file: file, line: line
        )
        XCTAssertGreaterThan(
            initial.total, 500_000,
            "Large dataset should have >500k rows — got \(initial.total). Did prepare_ci.sh download the right file?",
            file: file, line: line
        )

        // Pan the chart right-to-left repeatedly. TradingView lightweight charts
        // treats mouse drag as a pan, which fires onScrollChange → handleScrollChange
        // → loadMoreAtBeginning once the visible range's localFromIndex drops below 200.
        let chart = app.webViews.firstMatch
        XCTAssertTrue(
            chart.waitForExistence(timeout: 10),
            "Chart WebView not found",
            file: file, line: line
        )

        // Resolve the WebView frame once. Every time an XCUICoordinate is *used*,
        // XCUI re-queries its anchor element — resolving the WebView walks the
        // full DOM accessibility tree (~3s on macOS 26). Anchoring drag
        // coordinates to a window (cheap to resolve) keeps per-drag overhead in
        // the tens of ms instead of ~6s for both endpoints.
        let chartFrame = chart.frame
        let window = app.windows.firstMatch
        XCTAssertTrue(
            window.waitForExistence(timeout: 5),
            "App window not found",
            file: file, line: line
        )
        let windowOrigin = window.frame.origin
        let windowAnchor = window.coordinate(withNormalizedOffset: .zero)
        let start = windowAnchor.withOffset(CGVector(
            dx: chartFrame.minX - windowOrigin.x + chartFrame.width * 0.15,
            dy: chartFrame.midY - windowOrigin.y
        ))
        let end = windowAnchor.withOffset(CGVector(
            dx: chartFrame.minX - windowOrigin.x + chartFrame.width * 0.95,
            dy: chartFrame.midY - windowOrigin.y
        ))

        let dragCount = 10
        for _ in 0 ..< dragCount {
            start.press(forDuration: 0.05, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.6)
        }

        // Wait for the counter to grow past the initial buffer. loadChunkSize
        // defaults to bufferSize (500), so a single load bumps 500 → 1000.
        Self.waitForLoadedGreaterThan(initial.loaded, counter: counter, timeout: 20)
        let final = UITestUtils.readRecordCount(counter)
        XCTAssertGreaterThan(
            final.loaded, initial.loaded,
            "Loaded count stayed at \(final.loaded) after \(dragCount) left-drags — scroll-to-load regressed",
            file: file, line: line
        )
    }

    // MARK: - Fixtures & launch

    private func requireLargeDatasetFixture(projectName: String) throws -> URL {
        let projectURL = UITestUtils.testProjectURL(name: projectName, filePath: #filePath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: projectURL.path),
            "Fixture missing at \(projectURL.path). Run scripts/prepare_ci.sh."
        )

        let datasetURL = projectURL
            .deletingLastPathComponent()
            .appendingPathComponent(Self.largeDatasetRelativePath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: datasetURL.path),
            "Large parquet missing at \(datasetURL.path). Run scripts/prepare_ci.sh."
        )
        return projectURL
    }

    private func launch(projectURL: URL) -> XCUIApplication {
        let app = XCUIApplication()
        // `-NSQuitAlwaysKeepsWindows NO` disables macOS's state restoration so
        // previously-open documents don't reappear alongside our fixture.
        app.launchArguments = [
            projectURL.path,
            "-ArgoDisableUpdates", "-ArgoResetState",
            "-NSQuitAlwaysKeepsWindows", "NO",
        ]
        app.launchEnvironment["ARGO_DISABLE_UPDATES"] = "1"
        app.launchEnvironment["ARGO_RESET_STATE"] = "1"
        app.launch()
        app.fullScreen()
        return app
    }

    // MARK: - Counter polling

    /// Poll the counter until the predicate holds or the timeout expires.
    /// Avoids `XCTNSPredicateExpectation`, which relies on KVO that XCUIElement
    /// doesn't emit — in practice the expectation evaluated once at t=0 and
    /// never re-polled, so the waiter always timed out with stale state.
    @discardableResult
    private static func pollLabel(
        _ counter: XCUIElement,
        timeout: TimeInterval,
        poll: TimeInterval = 0.5,
        until: (_ parsed: (loaded: Int, total: Int)) -> Bool
    ) -> (loaded: Int, total: Int) {
        let deadline = Date().addingTimeInterval(timeout)
        var last = (loaded: 0, total: 0)
        while Date() < deadline {
            last = UITestUtils.readRecordCount(counter)
            if until(last) { return last }
            Thread.sleep(forTimeInterval: poll)
        }
        // Surface the final observed text so a timeout explains itself.
        let rawValue = counter.value as? String ?? ""
        print("[ScrollChartUITests] pollLabel timed out; value=\(rawValue.debugDescription) label=\(counter.label.debugDescription) parsed=\(last)")
        return last
    }

    private static func waitForNonZeroLoaded(_ counter: XCUIElement, timeout: TimeInterval) {
        _ = pollLabel(counter, timeout: timeout) { parsed in
            parsed.loaded > 0 && parsed.total > 0
        }
    }

    private static func waitForLoadedGreaterThan(
        _ threshold: Int, counter: XCUIElement, timeout: TimeInterval
    ) {
        _ = pollLabel(counter, timeout: timeout) { parsed in
            parsed.loaded > threshold
        }
    }
}
