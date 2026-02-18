//
//  TradingSessionRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingSessionRow: View {
    let session: TradingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.providerName)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                statusBadge
            }

            HStack(spacing: 8) {
                if let startedAt = session.startedAt {
                    Text(startedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.tradeCount > 0 {
                    Text("\(session.tradeCount) trades")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.pnl != 0 {
                    Text(formatPnl(session.pnl))
                        .font(.caption)
                        .foregroundStyle(session.pnl >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(session.status.title)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch session.status {
        case .idle: return .secondary
        case .prefetching, .connecting: return .orange
        case .running: return .green
        case .stopped: return .secondary
        case .error: return .red
        }
    }

    private func formatPnl(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "-$"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
