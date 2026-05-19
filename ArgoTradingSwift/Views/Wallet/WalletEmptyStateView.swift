//
//  WalletEmptyStateView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletEmptyStateView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Wallet unavailable")
                .font(.title3.weight(.semibold))
            Text("Start a live trading session to view balances, assets, and order history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
