//
//  WalletWindowView.swift
//  ArgoTradingSwift
//

import SwiftUI

enum WalletTab: String, CaseIterable, Identifiable {
    case assets
    case orders

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .assets: return "Assets"
        case .orders: return "Orders"
        }
    }
}

struct WalletWindowView: View {
    @Environment(TradingService.self) private var tradingService
    @Environment(WalletService.self) private var walletService

    @AppStorage(WalletDisplayPreferences.userDefaultsKey)
    private var baseCurrency: String = WalletDisplayPreferences.defaultCurrency

    @State private var selectedTab: WalletTab = .assets

    var body: some View {
        ZStack {
            if tradingService.walletAccessibleEngine == nil {
                WalletEmptyStateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: tradingService.walletAccessibleEngine == nil)
        .containerBackground(.ultraThinMaterial, for: .window)
        .task(id: walletTaskKey) {
            walletService.loadSupportedCurrencies()
            if tradingService.walletAccessibleEngine != nil {
                await walletService.refresh(baseCurrency: baseCurrency)
            }
        }
        .onChange(of: baseCurrency) { _, new in
            walletService.scheduleRefresh(baseCurrency: new)
        }
        .onChange(of: tradingService.liveDataChange) { _, change in
            guard let change else { return }
            guard change.finalized
                || change.contains(.orders)
                || change.contains(.stats)
            else { return }
            walletService.scheduleRefresh(baseCurrency: baseCurrency)
        }
        .onChange(of: selectedTab) { _, new in
            if new == .orders {
                walletService.markOrdersViewed()
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                WalletHeaderView(baseCurrency: $baseCurrency)
                WalletQuickActionsView(baseCurrency: baseCurrency)
                WalletTabsView(selection: $selectedTab)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .id(selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .scrollContentBackground(.hidden)
        }
        .animation(.smooth(duration: 0.25), value: walletService.assets)
        .animation(.smooth(duration: 0.25), value: walletService.balance)
        .animation(.smooth(duration: 0.25), value: walletService.buyingPower)
        .animation(.smooth(duration: 0.25), value: walletService.orders)
        .animation(.smooth(duration: 0.25), value: selectedTab)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .assets:
            WalletAssetsListView(baseCurrency: baseCurrency)
        case .orders:
            WalletOrdersListView(baseCurrency: baseCurrency)
        }
    }

    /// Triggers `task` to re-run whenever the wallet engine becomes available
    /// or the user starts a live trading session (which swaps the underlying
    /// engine instance).
    private var walletTaskKey: String {
        let hasEngine = tradingService.walletAccessibleEngine != nil ? "1" : "0"
        let running = tradingService.isRunning ? "1" : "0"
        return "\(hasEngine)-\(running)"
    }
}
