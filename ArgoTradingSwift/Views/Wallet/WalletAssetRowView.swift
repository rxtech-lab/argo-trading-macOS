//
//  WalletAssetRowView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletAssetRowView: View {
    let asset: WalletAsset
    let baseCurrency: String

    var body: some View {
        HStack(spacing: 12) {
            symbolBadge
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(quantityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(valueText)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(asset.symbol)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var symbolBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(asset.symbol.prefix(2))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var gradientColors: [Color] {
        let hash = asset.symbol.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let palette: [[Color]] = [
            [.orange, .pink],
            [.blue, .purple],
            [.teal, .indigo],
            [.green, .mint],
            [.yellow, .orange],
            [.pink, .red]
        ]
        return palette[abs(hash) % palette.count]
    }

    private var quantityText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: asset.quantity)) ?? "\(asset.quantity)"
    }

    private var valueText: String {
        guard let value = asset.baseCurrencyValue else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = asset.baseCurrency ?? baseCurrency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
