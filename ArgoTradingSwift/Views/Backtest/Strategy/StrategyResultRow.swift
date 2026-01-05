//
//  StrategyResultRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/4/26.
//

import SwiftUI

struct StrategyResultRow: View {
    let resultItem: BacktestResultItem

    private var result: BacktestResult { resultItem.result }

    private var pnlColor: Color {
        result.tradePnl.totalPnl >= 0 ? .green : .red
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(result.symbol)
                        .fontWeight(.medium)
                    if let parsed = resultItem.parsedFileName {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(parsed.timespan)
                            .foregroundStyle(.secondary)
                    }
                }

                if let parsed = resultItem.parsedFileName {
                    Text(parsed.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(formatWinRate(result.tradeResult.winRate))
                        .foregroundStyle(.secondary)
                    Text(formatPnl(result.tradePnl.totalPnl))
                        .foregroundStyle(pnlColor)
                        .fontWeight(.medium)
                }
                Text(resultItem.runTimestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatPnl(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+$"
        formatter.negativePrefix = "-$"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    private func formatWinRate(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }
}
