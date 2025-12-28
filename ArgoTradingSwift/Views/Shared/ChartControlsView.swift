//
//  ChartControlsView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Reusable chart controls with interval selector and chart type picker
struct ChartControlsView: View {
    let availableIntervals: [ChartTimeInterval]
    @Binding var selectedInterval: ChartTimeInterval
    @Binding var chartType: ChartType
    let isLoading: Bool
    var onIntervalChange: ((ChartTimeInterval) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Interval selector
            HStack(spacing: 4) {
                Text("Interval:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Interval", selection: Binding(
                    get: { selectedInterval },
                    set: { newInterval in
                        selectedInterval = newInterval
                        onIntervalChange?(newInterval)
                    }
                )) {
                    ForEach(availableIntervals) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .disabled(isLoading)
            }

            // Loading indicator
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            }

            Spacer()

            // Chart type picker
            Picker("", selection: $chartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
        .frame(height: 32)
    }
}
