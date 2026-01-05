//
//  ModeService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

enum NavigationPath: Hashable {
    case backtest(backtest: BacktestSelection?)
}

@Observable
class NavigationService {
    private var pathStack: [NavigationPath] = [.backtest(backtest: nil)] {
        didSet {
            guard let lastPath = pathStack.last else { return }
            switch lastPath {
            case .backtest(let selection):
                switch selection {
                case .data, .strategy:
                    currentSelectedBacktestTab = .general

                case .result:
                    currentSelectedBacktestTab = .results

                default:
                    break
                }

            default:
                return
            }
        }
    }

    var selectedMode: EditorMode = .Backtest
    var currentSelectedBacktestTab: BacktestTabs = .general

    /// Current navigation path (settable for SwiftUI binding compatibility)
    var path: NavigationPath {
        get {
            pathStack.last ?? .backtest(backtest: nil)
        }
        set {
            // When set via binding (e.g., sidebar selection), replace current path
            if pathStack.isEmpty {
                pathStack = [newValue]
            } else {
                pathStack[pathStack.count - 1] = newValue
            }
        }
    }

    var canGoBack: Bool {
        pathStack.count > 1
    }

    /// Push a new path onto the stack (preserves history for back navigation)
    func push(_ path: NavigationPath) {
        pathStack.append(path)
    }

    /// Pop the current path and return to the previous one
    func pop() {
        if pathStack.count > 1 {
            pathStack.removeLast()
        }
    }
}
