//
//  ChartControlsView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Reusable chart controls with interval selector, chart type picker, and indicators
struct ChartControlsView: View {
    let availableIntervals: [ChartTimeInterval]
    @Binding var selectedInterval: ChartTimeInterval
    @Binding var chartType: ChartType
    @Binding var indicatorSettings: IndicatorSettings
    let isLoading: Bool
    var onIntervalChange: ((ChartTimeInterval) -> Void)?
    var onIndicatorsChange: ((IndicatorSettings) -> Void)?

    @State private var showIndicatorPopover = false

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

            // Indicators button
            Button {
                showIndicatorPopover.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Indicators")
                        .font(.caption)
                    if !indicatorSettings.enabledIndicators.isEmpty {
                        Text("(\(indicatorSettings.enabledIndicators.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showIndicatorPopover) {
                IndicatorPopoverView(
                    settings: $indicatorSettings,
                    onSettingsChange: { newSettings in
                        onIndicatorsChange?(newSettings)
                    }
                )
            }

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
