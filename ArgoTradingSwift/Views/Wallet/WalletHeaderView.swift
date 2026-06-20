//
//  WalletHeaderView.swift
//  ArgoTradingSwift
//

import SwiftUI

struct WalletHeaderView: View {
    @Environment(WalletService.self) private var walletService
    @Environment(TradingService.self) private var tradingService

    @Binding var baseCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                accountBadge
                Spacer(minLength: 8)
                currencyPicker
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(formatted(walletService.balance?.value ?? 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                    .monospacedDigit()

                HStack(spacing: 6) {
                    Text("Buying Power")
                        .foregroundStyle(.secondary)
                    Text(formatted(walletService.buyingPower?.value ?? 0))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .font(.subheadline)
            }

            if let updated = walletService.lastUpdated {
                Text("Last updated \(updated, formatter: Self.timestampFormatter)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var accountBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.linearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(accountLabel)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                if !tradingService.currentSymbols.isEmpty {
                    Text(tradingService.currentSymbols.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var currencyPicker: some View {
        Picker(selection: $baseCurrency) {
            ForEach(walletService.supportedCurrencies, id: \.self) { currency in
                Text(currency).tag(currency)
            }
        } label: {
            Text("Currency")
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(minWidth: 80)
    }

    private var accountLabel: String {
        if tradingService.isRunning {
            return String(localized: "Live Session")
        }
        return String(localized: "Wallet")
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
