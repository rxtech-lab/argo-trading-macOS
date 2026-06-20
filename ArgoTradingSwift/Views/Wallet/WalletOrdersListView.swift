//
//  WalletOrdersListView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletOrdersListView: View {
    @Environment(WalletService.self) private var walletService

    let baseCurrency: String

    var body: some View {
        VStack(spacing: 10) {
            if walletService.orders.isEmpty {
                emptyState
            } else {
                ForEach(walletService.orders) { order in
                    WalletOrderRowView(order: order, baseCurrency: baseCurrency)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No orders yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial.opacity(0.5))
        )
    }
}
