//
//  ChartLegendView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import LightweightChart
import SwiftUI

/// Reusable chart legend displaying OHLCV values for a selected data point
struct ChartLegendView: View {
    let priceData: PriceData?
    var placeholderText: String = "Hover over chart to see values"

    var body: some View {
        Group {
            if let item = priceData {
                HStack(spacing: 16) {
                    Group {
                        LegendItem(label: "O", value: item.open, color: .primary)
                        LegendItem(label: "H", value: item.high, color: .green)
                        LegendItem(label: "L", value: item.low, color: .red)
                        LegendItem(label: "C", value: item.close, color: item.close >= item.open ? .green : .red)
                        LegendItem(label: "V", value: item.volume, color: .blue, decimals: 0)
                    }
                }
                .font(.system(.body, design: .monospaced))
            } else {
                Text(placeholderText)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 24)
    }
}
