//
//  WalletToolbarButton.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletToolbarButton: View {
    @Binding var document: ArgoTradingDocument
    @Environment(\.openWindow) private var openWindow
    @Environment(TradingService.self) private var tradingService
    @Environment(KeychainService.self) private var keychainService

    @State private var isConnecting = false

    var body: some View {
        Button {
            Task { await openWallet() }
        } label: {
            if isConnecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Wallet", systemImage: "wallet.pass")
            }
        }
        .disabled(isConnecting || !canOpen)
        .help(helpText)
    }

    private var canOpen: Bool {
        tradingService.walletAccessibleEngine != nil
            || document.selectedTradingProvider != nil
    }

    private var helpText: LocalizedStringKey {
        if tradingService.walletAccessibleEngine != nil {
            return "Open Wallet"
        }
        if document.selectedTradingProvider != nil {
            return "Connect provider and open wallet"
        }
        return "Select a trading provider to enable the wallet"
    }

    private func openWallet() async {
        if tradingService.walletAccessibleEngine == nil,
           let provider = document.selectedTradingProvider
        {
            isConnecting = true
            _ = await tradingService.connectWalletProvider(
                provider: provider,
                keychainService: keychainService
            )
            isConnecting = false
        }
        openWindow(id: "wallet")
    }
}
