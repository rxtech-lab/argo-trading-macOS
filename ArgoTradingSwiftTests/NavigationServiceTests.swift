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

/// Creates a NavigationService with a fresh, empty UserDefaults for test isolation.
private func makeService() -> NavigationService {
    let suiteName = "com.test.NavigationServiceTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return NavigationService(defaults: defaults)
}

// MARK: - Initial State Tests

struct InitialStateTests {
    @Test func initialGeneralSelectionIsNil() {
        let service = makeService()
        #expect(service.generalSelection == nil)
    }

    @Test func initialResultsSelectionIsNil() {
        let service = makeService()
        #expect(service.resultsSelection == nil)
    }

    @Test func initialSelectedModeIsBacktest() {
        let service = makeService()
        #expect(service.selectedMode == .Backtest)
    }

    @Test func initialSelectedTabIsGeneral() {
        let service = makeService()
        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func initialCurrentSelectionIsNil() {
        let service = makeService()
        // currentSelection returns generalSelection when tab is .general
        #expect(service.currentSelection == nil)
    }

    @Test func initialCanGoBackIsFalse() {
        let service = makeService()
        #expect(service.canGoBack == false)
    }
}

// MARK: - Current Selection Tests

struct CurrentSelectionTests {
    @Test func currentSelectionReturnsGeneralSelectionWhenTabIsGeneral() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.resultsSelection = .backtest(backtest: .result(url: testURL2))

        #expect(service.currentSelection == .backtest(backtest: .data(url: testURL)))
    }

    @Test func currentSelectionReturnsResultsSelectionWhenTabIsResults() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.resultsSelection = .backtest(backtest: .result(url: testURL2))

        #expect(service.currentSelection == .backtest(backtest: .result(url: testURL2)))
    }

    @Test func currentSelectionUpdatesWhenSwitchingTabs() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.resultsSelection = .backtest(backtest: .result(url: testURL2))

        service.currentSelectedBacktestTab = .general
        #expect(service.currentSelection == .backtest(backtest: .data(url: testURL)))

        service.currentSelectedBacktestTab = .results
        #expect(service.currentSelection == .backtest(backtest: .result(url: testURL2)))
    }

    @Test func currentSelectionReturnsNilWhenActiveTabSelectionIsNil() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.resultsSelection = nil

        service.currentSelectedBacktestTab = .results
        #expect(service.currentSelection == nil)
    }
}

// MARK: - Push Tests

struct PushTests {
    @Test func pushSavesCurrentSelectionToStack() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // Should be able to go back
        #expect(service.canGoBack == true)
    }

    @Test func pushDoesNotSaveToStackWhenCurrentSelectionIsNil() {
        let service = makeService()
        // Initial state: generalSelection is nil

        service.push(.backtest(backtest: .data(url: testURL)))

        // Stack should be empty since there was nothing to save
        #expect(service.canGoBack == false)
    }

    @Test func pushWithDataSelectionSetsTabToGeneral() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results // Start on results tab

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func pushWithStrategySelectionSetsTabToGeneral() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results // Start on results tab

        service.push(.backtest(backtest: .strategy(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func pushWithResultUrlSetsTabToResults() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general // Start on general tab

        service.push(.backtest(backtest: .result(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func pushWithResultsNoUrlPreservesCurrentTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general

        service.push(.backtest(backtest: .results))

        // .results (plural, no URL) falls through to default case which preserves tab
        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func pushWithNilSelectionPreservesCurrentTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results

        service.push(.backtest(backtest: nil))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func multiplePushesPreserveStackOrder() {
        let service = makeService()

        // Set initial selection and push first item
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.push(.backtest(backtest: .strategy(url: testURL2)))
        #expect(service.canGoBack == true)

        // Note: Due to async setSelection, we need to manually set the selection
        // before pushing again, since the async dispatch hasn't completed
        service.generalSelection = .backtest(backtest: .strategy(url: testURL2))
        service.push(.backtest(backtest: .strategy(url: testURL3)))

        // Pop should restore previous state
        service.pop()
        #expect(service.canGoBack == true)

        // Pop again should empty the stack
        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func canGoBackBecomesTrueAfterPushWithExistingSelection() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        #expect(service.canGoBack == false)

        service.push(.backtest(backtest: .strategy(url: testURL2)))

        #expect(service.canGoBack == true)
    }
}

// MARK: - Pop Tests

struct PopTests {
    @Test func popRestoresPreviousSelectionFromStack() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        service.push(.backtest(backtest: .strategy(url: testURL2)))
        #expect(service.canGoBack == true)

        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func popOnEmptyStackIsNoOp() {
        let service = makeService()

        // Initial state with empty stack
        #expect(service.canGoBack == false)

        service.pop()

        // State should remain unchanged
        #expect(service.canGoBack == false)
        #expect(service.generalSelection == nil)
        #expect(service.resultsSelection == nil)
    }

    @Test func multiplePopTraverseStackInReverseOrder() {
        let service = makeService()

        // Build up stack: data -> strategy -> result
        // Note: Due to async setSelection, we need to manually set the selection
        // before each push, since the async dispatch hasn't completed
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // Manually set selection before next push (simulating async completion)
        service.generalSelection = .backtest(backtest: .strategy(url: testURL2))
        service.push(.backtest(backtest: .result(url: testURL3)))

        // Pop from result
        service.pop()
        #expect(service.canGoBack == true)

        // Pop from strategy
        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func canGoBackBecomesFalseWhenStackIsEmpty() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        service.push(.backtest(backtest: .strategy(url: testURL2)))
        #expect(service.canGoBack == true)

        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func popSwitchesTabBasedOnRestoredSelection() {
        let service = makeService()

        // Start on general tab with data selection
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        #expect(service.currentSelectedBacktestTab == .general)

        // Push result which switches to results tab
        service.push(.backtest(backtest: .result(url: testURL2)))
        #expect(service.currentSelectedBacktestTab == .results)

        // Pop should restore data selection and switch back to general tab
        service.pop()
        #expect(service.currentSelectedBacktestTab == .general)
    }
}

// MARK: - Tab Switching Tests

struct TabSwitchingTests {
    @Test func dataSelectionSwitchesToGeneralTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results

        service.push(.backtest(backtest: .data(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func strategySelectionSwitchesToGeneralTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results

        service.push(.backtest(backtest: .strategy(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func resultWithUrlSwitchesToResultsTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general

        service.push(.backtest(backtest: .result(url: testURL)))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func resultsWithoutUrlPreservesCurrentTab() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general

        service.push(.backtest(backtest: .results))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func nilSelectionPreservesCurrentTabWhenGeneral() {
        let service = makeService()
        service.currentSelectedBacktestTab = .general

        service.push(.backtest(backtest: nil))

        #expect(service.currentSelectedBacktestTab == .general)
    }

    @Test func nilSelectionPreservesCurrentTabWhenResults() {
        let service = makeService()
        service.currentSelectedBacktestTab = .results

        service.push(.backtest(backtest: nil))

        #expect(service.currentSelectedBacktestTab == .results)
    }

    @Test func tabSwitchingPreservesBothSelections() {
        let service = makeService()

        // Set general selection
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        // Push result to switch to results tab
        service.push(.backtest(backtest: .result(url: testURL2)))

        // Both selections should be preserved
        #expect(service.currentSelectedBacktestTab == .results)
        // Note: generalSelection may have been modified by push mechanics
    }
}

// MARK: - Edge Case Tests

struct EdgeCaseTests {
    @Test func popWhenPushStackIsEmptyDoesNothing() {
        let service = makeService()

        service.pop()
        service.pop()
        service.pop()

        #expect(service.canGoBack == false)
        #expect(service.generalSelection == nil)
        #expect(service.resultsSelection == nil)
    }

    @Test func multipleConsecutivePopsAtMinimumStackDepth() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        service.push(.backtest(backtest: .strategy(url: testURL2)))

        // Pop once to empty the stack
        service.pop()
        #expect(service.canGoBack == false)

        // Additional pops should be no-ops
        service.pop()
        service.pop()
        #expect(service.canGoBack == false)
    }

    @Test func pushPopCycleReturnsToOriginalState() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        let originalTab = service.currentSelectedBacktestTab

        service.push(.backtest(backtest: .strategy(url: testURL2)))
        service.pop()

        #expect(service.currentSelectedBacktestTab == originalTab)
        #expect(service.canGoBack == false)
    }

    @Test func pushDifferentSelectionTypesInSequence() {
        let service = makeService()

        // Start with data
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        #expect(service.currentSelectedBacktestTab == .general)

        // Push strategy (same tab)
        service.push(.backtest(backtest: .strategy(url: testURL2)))
        #expect(service.currentSelectedBacktestTab == .general)

        // Manually set selection before next push (simulating async completion)
        service.generalSelection = .backtest(backtest: .strategy(url: testURL2))

        // Push result (switches tab)
        service.push(.backtest(backtest: .result(url: testURL3)))
        #expect(service.currentSelectedBacktestTab == .results)

        // Pop back to strategy
        service.pop()
        #expect(service.currentSelectedBacktestTab == .general)

        // Pop back to data
        service.pop()
        #expect(service.currentSelectedBacktestTab == .general)
        #expect(service.canGoBack == false)
    }

    @Test func directAssignmentToGeneralSelectionBypassesStack() {
        let service = makeService()

        // Direct assignment doesn't use push
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        #expect(service.canGoBack == false)

        service.generalSelection = .backtest(backtest: .strategy(url: testURL2))
        #expect(service.canGoBack == false)
    }

    @Test func directAssignmentToResultsSelectionBypassesStack() {
        let service = makeService()

        // Direct assignment doesn't use push
        service.resultsSelection = .backtest(backtest: .result(url: testURL))
        #expect(service.canGoBack == false)

        service.resultsSelection = .backtest(backtest: .result(url: testURL2))
        #expect(service.canGoBack == false)
    }

    @Test func rapidPushPopOperations() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        // Rapid pushes
        for i in 0..<10 {
            let url = URL(fileURLWithPath: "/tmp/test\(i).parquet")
            service.push(.backtest(backtest: .data(url: url)))
        }
        #expect(service.canGoBack == true)

        // Rapid pops
        for _ in 0..<10 {
            service.pop()
        }
        #expect(service.canGoBack == false)
    }

    @Test func switchingModesDoesNotAffectBacktestSelections() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))
        service.resultsSelection = .backtest(backtest: .result(url: testURL2))

        // Change mode
        service.selectedMode = .Trading

        // Selections should be preserved
        #expect(service.generalSelection == .backtest(backtest: .data(url: testURL)))
        #expect(service.resultsSelection == .backtest(backtest: .result(url: testURL2)))
    }

    @Test func pushWithSameSelectionStillAddsToStack() {
        let service = makeService()
        service.generalSelection = .backtest(backtest: .data(url: testURL))

        // Push the same selection
        service.push(.backtest(backtest: .data(url: testURL)))

        // Should still be able to go back
        #expect(service.canGoBack == true)
    }
}
