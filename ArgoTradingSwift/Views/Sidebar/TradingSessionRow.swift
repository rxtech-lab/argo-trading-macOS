//
//  TradingSessionRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingRunRow: View {
    let resultItem: TradingResultItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(resultItem.result.strategy.name.isEmpty ? resultItem.result.id : resultItem.result.strategy.name)
                    .font(.body)
                    .lineLimit(1)

                Spacer()

                Text(resultItem.result.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(resultItem.displayTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !resultItem.displaySymbols.isEmpty {
                    Text(resultItem.displaySymbols)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if resultItem.result.tradeResult.numberOfTrades > 0 {
                    Text("\(resultItem.result.tradeResult.numberOfTrades) trades")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if resultItem.result.tradePnl.totalPnl != 0 {
                    Text(formatPnl(resultItem.result.tradePnl.totalPnl))
                        .font(.caption)
                        .foregroundStyle(resultItem.result.tradePnl.totalPnl >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 2)
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
