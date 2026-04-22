//
//  Utils.swift
//  ArgoTradingSwiftUITests
//
//  Created by Qiwei Li on 4/20/25.
//

import XCTest

enum UITestUtils {
    /// Resolve a `.rxtrading` fixture under `testdata/` by walking up from the
    /// source file to the repo root. Pass `name` (without extension) to select
    /// a specific fixture; defaults to the shared "Test project".
    /// `#filePath` is baked in at compile time, so this works on any machine that built the test bundle.
    static func testProjectURL(name: String = "Test project", filePath: String = #filePath) -> URL {
        self.testdataDir(filePath: filePath).appendingPathComponent("\(name).rxtrading")
    }

    private static func testdataDir(filePath: String) -> URL {
        let thisFile = URL(fileURLWithPath: filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // ArgoTradingSwiftUITests/
            .deletingLastPathComponent() // repo root
        return repoRoot.appendingPathComponent("testdata")
    }

    /// Clears the contents of the results directory without removing the directory itself.
    /// This avoids sandbox permission issues in UI tests.
    static func clearResults(at url: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            // Directory doesn't exist or can't be read; try to create it
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                print("Failed to create results directory at \(url): \(error)")
            }
            return
        }
        for item in contents {
            do {
                try fm.removeItem(at: item)
            } catch {
                print("Failed to remove \(item.lastPathComponent): \(error)")
            }
        }
    }

    /// Parses the `argo.priceChart.recordCount` label "Showing 500 of 675840 records"
    /// into its two integers. Returns `(0, 0)` if the label can't be parsed.
    static func parseRecordCount(_ label: String) -> (loaded: Int, total: Int) {
        let numbers = label
            .replacingOccurrences(of: ",", with: "")
            .components(separatedBy: .whitespaces)
            .compactMap(Int.init)
        guard numbers.count >= 2 else { return (0, 0) }
        return (numbers[0], numbers[1])
    }

    /// Reads the record-count string from an XCUIElement. On macOS, SwiftUI
    /// `Text` exposes its content as `AXValue` (-> `element.value`) rather than
    /// `AXLabel`, so `element.label` is often empty. Try value first, then
    /// fall back to label/title so the helper stays robust across platforms
    /// and SwiftUI versions.
    static func readRecordCount(_ element: XCUIElement) -> (loaded: Int, total: Int) {
        let candidates: [String] = [
            element.value as? String,
            element.label,
            element.title,
        ].compactMap { $0 }.filter { !$0.isEmpty }
        for text in candidates {
            let parsed = parseRecordCount(text)
            if parsed.loaded > 0 || parsed.total > 0 { return parsed }
        }
        return (0, 0)
    }

    static func findResultsTab(in app: XCUIApplication) -> XCUIElement {
        let candidates: [XCUIElement] = [
            app.buttons.matching(identifier: "argo.backtestTab.Results").firstMatch,
            app.radioButtons.matching(identifier: "argo.backtestTab.Results").firstMatch,
            app.buttons["Results"].firstMatch,
            app.radioButtons["Results"].firstMatch,
            app.segmentedControls.buttons["Results"].firstMatch,
        ]
        return candidates.first { $0.exists } ?? candidates[2]
    }
}

extension XCUIElement {
    func waitUntilEnabled(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if exists && isEnabled { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return exists && isEnabled
    }
}

extension XCUIApplication {
    func fullScreen() {
        let zoomButton = self.buttons["_XCUI:ZoomWindow"].firstMatch
        let fullscreenButton = self.buttons["XCUI:FullScreenWindow"].firstMatch

        if zoomButton.waitForExistence(timeout: 5) {
            zoomButton.click()
        } else if fullscreenButton.waitForExistence(timeout: 5) {
            fullscreenButton.click()
        }
    }
}
