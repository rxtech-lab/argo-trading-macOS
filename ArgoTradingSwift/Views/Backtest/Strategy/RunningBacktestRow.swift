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
        }
        .padding(.vertical, 4)
    }
}
