//
//  WalletOrderRowView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletOrderRowView: View {
    let order: WalletOrder
    let baseCurrency: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            sideBadge

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(order.symbol)
                        .font(.system(size: 14, weight: .semibold))
                    Text(order.status)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(.secondary.opacity(0.15))
                        )
                        .foregroundStyle(.secondary)
                }
                Text(order.executedAt, formatter: Self.timestampFormatter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.system(size: 14, weight: .medium))
                    .monospacedDigit()
                Text(priceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
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

    private var sideBadge: some View {
        let isBuy = order.side.uppercased() == "BUY"
        return ZStack {
            Circle()
                .fill(isBuy ? Color.green.opacity(0.25) : Color.red.opacity(0.25))
            Image(systemName: isBuy ? "arrow.down" : "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isBuy ? Color.green : Color.red)
        }
        .frame(width: 32, height: 32)
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        let qty = formatter.string(from: NSNumber(value: order.executedQty)) ?? "\(order.executedQty)"
        return "\(qty) \(symbolBase)"
    }

    private var priceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrency
        formatter.maximumFractionDigits = 4
        return formatter.string(from: NSNumber(value: order.executedPrice)) ?? "\(order.executedPrice)"
    }

    /// Best-effort base extraction for display (e.g. `BTCUSDT` → `BTC`). Falls
    /// back to the full symbol when no common quote suffix matches.
    private var symbolBase: String {
        let quotes = ["USDT", "USDC", "BUSD", "USD", "BTC", "ETH"]
        for quote in quotes where order.symbol.hasSuffix(quote) && order.symbol.count > quote.count {
            return String(order.symbol.dropLast(quote.count))
        }
        return order.symbol
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}
