//
//  WalletTabsView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletTabsView: View {
    @Binding var selection: WalletTab
    @Environment(WalletService.self) private var walletService

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(WalletTab.allCases) { tab in
                tabLabel(tab).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .animation(.smooth(duration: 0.2), value: walletService.newOrdersCount)
    }

    @ViewBuilder
    private func tabLabel(_ tab: WalletTab) -> some View {
        if tab == .orders, walletService.newOrdersCount > 0 {
            HStack(spacing: 6) {
                Text(tab.label)
                badge(count: walletService.newOrdersCount)
            }
        } else {
            Text(tab.label)
        }
    }

    private func badge(count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .monospacedDigit()
            .contentTransition(.numericText())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .frame(minWidth: 16, minHeight: 16)
            .background(
                Capsule().fill(Color.red)
            )
    }
}
