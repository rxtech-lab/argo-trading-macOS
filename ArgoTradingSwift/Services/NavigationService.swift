//
//  ModeService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

enum NavigationPath: Hashable, Equatable {
    case backtest(backtest: BacktestSelection?)
}

@Observable
class NavigationService {
    /// Separate selection states for each tab
    var generalSelection: NavigationPath? = nil
    var resultsSelection: NavigationPath? = nil

    /// Stack for push-based navigation (back button only works for push operations)
    private var pushStack: [NavigationPath] = []

    var selectedMode: EditorMode = .Backtest
    var currentSelectedBacktestTab: BacktestTabs = .general

    /// Current selection based on the active tab
    var currentSelection: NavigationPath? {
        switch currentSelectedBacktestTab {
        case .general:
            return generalSelection
        case .results:
            return resultsSelection
        }
    }

    var canGoBack: Bool {
        !pushStack.isEmpty
    }

    /// Push a new path onto the stack (preserves history for back navigation)
    func push(_ path: NavigationPath) {
        // Save current selection to stack before navigating
        if let current = currentSelection {
            pushStack.append(current)
        }
        // Update the appropriate selection based on path type
        setSelection(path)
    }

    /// Pop the current path and return to the previous one
    func pop() {
        guard let previous = pushStack.popLast() else { return }
        setSelection(previous)
    }

    /// Set the appropriate selection based on path type
    private func setSelection(_ path: NavigationPath) {
        switch path {
        case .backtest(let selection):
            switch selection {
            case .data, .strategy:
                // Clear first, then set async to force SwiftUI to deselect
                generalSelection = nil
                DispatchQueue.main.async {
                    self.generalSelection = path
                }
                currentSelectedBacktestTab = .general
            case .result:
                // Clear first, then set async to force SwiftUI to deselect
                resultsSelection = nil
                DispatchQueue.main.async {
                    self.resultsSelection = path
                }
                currentSelectedBacktestTab = .results
            default:
                // For nil selection, update based on current tab
                switch currentSelectedBacktestTab {
                case .general:
                    generalSelection = nil
                    DispatchQueue.main.async {
                        self.generalSelection = path
                    }
                case .results:
                    resultsSelection = nil
                    DispatchQueue.main.async {
                        self.resultsSelection = path
                    }
                }
            }
        }
    }
}
