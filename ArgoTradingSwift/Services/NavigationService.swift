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
    var path: NavigationPath = .backtest(backtest: nil)
    var selectedMode: EditorMode = .Backtest
}
