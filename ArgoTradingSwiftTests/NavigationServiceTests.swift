//
//  NavigationServiceTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 1/5/26.
//

import Foundation
import Testing
@testable import ArgoTradingSwift

// MARK: - Test Helpers

let testURL = URL(fileURLWithPath: "/tmp/test.parquet")
let testURL2 = URL(fileURLWithPath: "/tmp/test2.parquet")
let testURL3 = URL(fileURLWithPath: "/tmp/test3.parquet")

// MARK: - Initial State Tests

struct InitialStateTests {
    @Test func initialPathIsBacktestWithNilSelection() {
        let service = NavigationService()

        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected backtest path")
        }
    }

    @Test func initialSelectedModeIsBacktest() {
        let service = NavigationService()
        #expect(service.selectedMode == .Backtest)
    }

    @Test func initialSelectedTabIsGeneral() {
        let service = NavigationService()
        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func initialCanGoBackIsFalse() {
        let service = NavigationService()
        #expect(service.canGoBack == false)
    }
}

// MARK: - Path Stack Edge Cases

struct PathStackTests {
    // Single item (edge case - can't pop below 1)
    @Test func popWithSingleItemDoesNotRemove() {
        let service = NavigationService()

        // Initially has 1 item
        #expect(service.canGoBack == false)

        // Pop should be a no-op
        service.pop()

        // Still has the same path
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected backtest path after pop")
        }
    }

    @Test func canGoBackIsFalseWithSingleItem() {
        let service = NavigationService()
        #expect(service.canGoBack == false)
    }

    // Multiple items
    @Test func pushAddsToStack() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.canGoBack == true)
        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        } else {
            Issue.record("Expected backtest path with data selection")
        }
    }

    @Test func popRemovesLastItem() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))
        #expect(service.canGoBack == true)

        service.pop()

        #expect(service.canGoBack == false)
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected backtest path with nil selection after pop")
        }
    }

    @Test func canGoBackIsTrueWithMultipleItems() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.canGoBack == true)
    }

    @Test func multiplePushesPreserveOrder() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))
        service.push(.backtest(backtest: .strategy(url: testURL2)))
        service.push(.backtest(backtest: .result(url: testURL3)))

        // Should be at result
        if case .backtest(let selection) = service.path {
            #expect(selection == .result(url: testURL3))
        } else {
            Issue.record("Expected result selection")
        }

        // Pop to strategy
        service.pop()
        if case .backtest(let selection) = service.path {
            #expect(selection == .strategy(url: testURL2))
        } else {
            Issue.record("Expected strategy selection")
        }

        // Pop to data
        service.pop()
        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        } else {
            Issue.record("Expected data selection")
        }
    }

    @Test func multiplePopsToPreviousStates() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))
        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // Pop twice
        service.pop()
        service.pop()

        // Should be back at initial state
        #expect(service.canGoBack == false)
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected nil selection")
        }
    }

    @Test func pathGetterReturnsFallbackWhenStackEmpty() {
        let service = NavigationService()

        // Even at initial state, path should return fallback
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected backtest path as fallback")
        }
    }
}

// MARK: - Path Setter Edge Cases

struct PathSetterTests {
    @Test func settingPathReplacesCurrentNotPush() {
        let service = NavigationService()

        // Set path (not push)
        service.path = .backtest(backtest: .data(url: testURL))

        // Should NOT be able to go back (replaced, not pushed)
        #expect(service.canGoBack == false)

        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        } else {
            Issue.record("Expected data selection")
        }
    }

    @Test func settingPathPreservesStackDepth() {
        let service = NavigationService()

        // Push one item
        service.push(.backtest(backtest: .data(url: testURL)))
        #expect(service.canGoBack == true)

        // Set path (should replace current, not push)
        service.path = .backtest(backtest: .strategy(url: testURL2))

        // Stack depth should remain the same (2 items)
        #expect(service.canGoBack == true)

        // Pop should go back to initial
        service.pop()
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected nil selection after pop")
        }
    }

    @Test func settingPathOnEmptyStackCreatesNewStack() {
        let service = NavigationService()

        // Set path
        service.path = .backtest(backtest: .data(url: testURL))

        // Verify path is set
        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        } else {
            Issue.record("Expected data selection")
        }
    }
}

// MARK: - Selected Tab Auto-Update Tests

struct SelectedTabTests {
    // Tab changes based on BacktestSelection
    @Test func dataSelectionSetsTabToGeneral() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .results // Start with results

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func strategySelectionSetsTabToGeneral() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .results // Start with results

        service.push(.backtest(backtest: .strategy(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func resultWithUrlSetsTabToResults() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .general // Start with general

        service.push(.backtest(backtest: .result(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func resultsWithoutUrlDoesNotChangeTab() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .general // Start with general

        // .results (plural, no URL) should NOT change tab
        service.push(.backtest(backtest: .results))

        // Tab should remain general (falls through to default case)
        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func nilSelectionDoesNotChangeTab() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .results // Start with results

        service.push(.backtest(backtest: nil))

        // Tab should remain results
        #expect(service.currentSelectedBacktestTab == .results)
    }

    // Tab changes via push vs setter
    @Test func pushingResultPathSetsTabToResults() {
        let service = NavigationService()

        service.push(.backtest(backtest: .result(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func pushingDataPathSetsTabToGeneral() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .results

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func settingPathToResultUpdatesTab() {
        let service = NavigationService()
        service.currentSelectedBacktestTab = .general

        service.path = .backtest(backtest: .result(url: testURL))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func tabPreservedWhenNavigatingToResults() {
        let service = NavigationService()

        // First set tab to results via .result(url:)
        service.push(.backtest(backtest: .result(url: testURL)))
        #expect(service.currentSelectedBacktestTab == .results)

        // Navigate to .results (plural) - tab should stay results
        service.push(.backtest(backtest: .results))
        #expect(service.currentSelectedBacktestTab == .results)
    }
}

// MARK: - Navigation Flow Tests

struct NavigationFlowTests {
    @Test func pushThenPopReturnsToOriginal() {
        let service = NavigationService()

        let originalPath = service.path

        service.push(.backtest(backtest: .data(url: testURL)))
        service.pop()

        if case .backtest(let originalSelection) = originalPath,
           case .backtest(let currentSelection) = service.path {
            #expect(originalSelection == currentSelection)
        } else {
            Issue.record("Paths should match after push/pop")
        }
    }

    @Test func multiplePushPopCycle() {
        let service = NavigationService()

        // Push data
        service.push(.backtest(backtest: .data(url: testURL)))
        #expect(service.canGoBack == true)

        // Push strategy
        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // Pop back to data
        service.pop()
        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        }

        // Push result
        service.push(.backtest(backtest: .result(url: testURL3)))

        // Pop back to data again
        service.pop()
        if case .backtest(let selection) = service.path {
            #expect(selection == .data(url: testURL))
        }

        // Pop back to initial
        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func pathGetterReturnsLastStackItem() {
        let service = NavigationService()

        service.push(.backtest(backtest: .data(url: testURL)))
        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // path should return the last pushed item
        if case .backtest(let selection) = service.path {
            #expect(selection == .strategy(url: testURL2))
        } else {
            Issue.record("Expected strategy selection")
        }
    }

    @Test func popAtMinimumStackDepthIsNoOp() {
        let service = NavigationService()

        // Try to pop multiple times at minimum depth
        service.pop()
        service.pop()
        service.pop()

        // Should still have initial state
        #expect(service.canGoBack == false)
        if case .backtest(let selection) = service.path {
            #expect(selection == nil)
        } else {
            Issue.record("Expected nil selection")
        }
    }
}
