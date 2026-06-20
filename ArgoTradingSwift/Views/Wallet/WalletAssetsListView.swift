//
//  WalletAssetsListView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletAssetsListView: View {
    @Environment(WalletService.self) private var walletService

    let baseCurrency: String

    var body: some View {
        VStack(spacing: 10) {
            if walletService.assets.isEmpty {
                emptyState
            } else {
                ForEach(walletService.assets) { asset in
                    WalletAssetRowView(asset: asset, baseCurrency: baseCurrency)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("No assets yet")
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
