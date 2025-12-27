//
//  ResultFileRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct ResultFileRow: View {
    let resultItem: BacktestResultItem

    var body: some View {
        if let parsed = resultItem.parsedFileName {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(parsed.ticker)
                        .fontWeight(.medium)
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                    Text(parsed.timespan)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                Text(resultItem.displayTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(resultItem.result.symbol)
                    .fontWeight(.medium)
                Text(resultItem.displayTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
