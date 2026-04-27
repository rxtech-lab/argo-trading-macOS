//
//  RunningBacktestRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/4/26.
//

import SwiftUI

struct RunningBacktestRow: View {
    let strategyName: String
    let progress: Progress
    let dataFile: String
    let barsPerSecond: Double
    let realizedPnL: Double

    private var hasLiveMetrics: Bool {
        barsPerSecond != 0 || realizedPnL != 0
    }

    private var pnlColor: Color {
        realizedPnL >= 0 ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.green)
                Text("Running Backtest")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(progress.percentage))%")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress.percentage, total: 100)
                .progressViewStyle(.linear)

            Text(dataFile)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if hasLiveMetrics {
                HStack {
                    Text("\(Int((barsPerSecond * 60).rounded())) bars/min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatPnl(realizedPnL))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(pnlColor)
                        .help("Realized profit and loss from closed trades so far in this backtest run. Updates live as the engine processes new bars.")
                }
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
}
