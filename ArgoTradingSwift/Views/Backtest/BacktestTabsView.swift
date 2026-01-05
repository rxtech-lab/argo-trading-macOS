//
//  BacktestTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import SwiftUI

struct BacktestTabsView: View {
    @Bindable var navigationService: NavigationService
    var body: some View {
        Picker("", selection: $navigationService.currentSelectedBacktestTab) {
            ForEach(BacktestTabs.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }
}
