//
//  ArgoTradingSwiftUITests.swift
//  ArgoTradingSwiftUITests
//
//  Created by Qiwei Li on 4/20/25.
//

import XCTest

final class ArgoTradingSwiftUITests: XCTestCase {
    func testOpenProjectRunBacktestAndSeeResult() throws {
        let projectURL = UITestUtils.testProjectURL(filePath: #filePath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: projectURL.path),
            "Fixture missing at \(projectURL.path)"
        )
        UITestUtils.clearResults(at: projectURL.deletingLastPathComponent().appendingPathComponent("result"))

        let app = XCUIApplication()
        app.launchArguments = [projectURL.path, "-ArgoDisableUpdates", "-ArgoResetState"]
        app.launchEnvironment["ARGO_DISABLE_UPDATES"] = "1"
        app.launchEnvironment["ARGO_RESET_STATE"] = "1"
        app.launch()

        app/*@START_MENU_TOKEN@*/ .buttons["BTCUSDT, •, 1 minute, Apr 18, 2026 - Apr 19, 2026"]/*[[".cells.buttons[\"BTCUSDT, •, 1 minute, Apr 18, 2026 - Apr 19, 2026\"]",".buttons[\"BTCUSDT, •, 1 minute, Apr 18, 2026 - Apr 19, 2026\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
        XCTAssertTrue(app/*@START_MENU_TOKEN@*/ .staticTexts["Price Chart"]/*[[".groups.staticTexts[\"Price Chart\"]",".staticTexts[\"Price Chart\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .waitForExistence(timeout: 20), "Price Chart not found after clicking fixture — it may take a while to load")

        app/*@START_MENU_TOKEN@*/ .buttons["place_order_plugin"]/*[[".cells.buttons[\"place_order_plugin\"]",".buttons[\"place_order_plugin\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
        XCTAssertTrue(app/*@START_MENU_TOKEN@*/ .staticTexts["PlaceOrderStrategy"]/*[[".groups.staticTexts[\"PlaceOrderStrategy\"]",".staticTexts[\"PlaceOrderStrategy\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .waitForExistence(timeout: 20), "PlaceOrderStrategy not found after clicking plugin — it may take a while to load")

        // full screen
        app.fullScreen()
        // Use firstMatch: SwiftUI toolbar buttons can expose nested accessibility elements
        // that inherit the same identifier from the parent.
        let runButton = app.buttons.matching(identifier: "argo.runBacktest").firstMatch
        XCTAssertTrue(runButton.waitForExistence(timeout: 20), "Run button not found after opening fixture")
        XCTAssertTrue(
            runButton.waitUntilEnabled(timeout: 10),
            "Run button stayed disabled — fixture schema/dataset/strategy did not resolve"
        )
        runButton.tap()
        // wait 10 seconds
        sleep(10)

        // Switch to Results tab. On macOS, SwiftUI's segmented Picker exposes items as
        // buttons/radioButtons whose identifier is the option's raw label, not whatever we
        // attached to the inner Text. Query by label text; try multiple element types.
        let resultsTab = UITestUtils.findResultsTab(in: app)
        XCTAssertTrue(resultsTab.waitForExistence(timeout: 10), "Results tab not found — hierarchy:\n\(app.debugDescription)")
        resultsTab.click()

        let resultRow = app.cells/*@START_MENU_TOKEN@*/ .element(boundBy: 1)/*[[".element(boundBy: 1)",".containing(.button, identifier: \"BTCUSDT, •, 1 minute, 15:16:29\").firstMatch"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/
        XCTAssertTrue(resultRow.waitForExistence(timeout: 30), "Result row not found after running backtest — it may take a while for the first result to appear")

        // click and navigate to trades tab, then click the first trade to see details
        resultRow.click()
        app/*@START_MENU_TOKEN@*/ .radioButtons["Trades"]/*[[".radioGroups.radioButtons[\"Trades\"]",".radioButtons[\"Trades\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
        app/*@START_MENU_TOKEN@*/ .staticTexts["BTCUSDT"]/*[[".groups.staticTexts[\"BTCUSDT\"]",".staticTexts[\"BTCUSDT\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()

        // webview should show the palceOrderstategy text in the chart
        XCTAssertTrue(app.staticTexts["PlaceOrderStrategy"].waitForExistence(timeout: 10), "Strategy name not found in result details")
    }
}
