//
//  WalletQuickActionsView.swift
//  ArgoTradingSwift
//

import AppKit
import SwiftUI

struct WalletQuickActionsView: View {
    @Environment(WalletService.self) private var walletService
    @Environment(TradingService.self) private var tradingService

    let baseCurrency: String

    var body: some View {
        HStack(spacing: 12) {
            actionButton(
                titleKey: "Refresh",
                systemImage: "arrow.clockwise",
                isLoading: walletService.isLoading
            ) {
                walletService.scheduleRefresh(baseCurrency: baseCurrency)
            }

            actionButton(
                titleKey: "Copy",
                systemImage: "doc.on.doc"
            ) {
                let symbols = tradingService.currentSymbols.joined(separator: ", ")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(symbols, forType: .string)
            }
            .disabled(tradingService.currentSymbols.isEmpty)

            actionButton(
                titleKey: "Receive",
                systemImage: "arrow.down.left.circle"
            ) {
                // Placeholder for future deposit flow.
            }
            .disabled(true)

            actionButton(
                titleKey: "Send",
                systemImage: "arrow.up.right.circle"
            ) {
                // Placeholder for future withdrawal flow.
            }
            .disabled(true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func actionButton(
        titleKey: LocalizedStringKey,
        systemImage: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(height: 22)

                Text(titleKey)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
