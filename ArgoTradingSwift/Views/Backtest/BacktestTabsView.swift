//
//  BacktestTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import SwiftUI

struct BacktestTabsView: View {
    @Bindable var backtestService: BacktestService
    var body: some View {
        Picker("", selection: $backtestService.currentBacktestTab) {
            ForEach(BacktestTabs.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }
}
