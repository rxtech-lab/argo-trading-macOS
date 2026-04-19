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
        testdataDir(filePath: filePath).appendingPathComponent("\(name).rxtrading")
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
