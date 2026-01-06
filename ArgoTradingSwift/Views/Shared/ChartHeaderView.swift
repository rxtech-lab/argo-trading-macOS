//
//  ChartHeaderView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import LightweightChart
import SwiftUI

/// Reusable chart header with title and zoom controls
struct ChartHeaderView: View {
    let title: String
    @Binding var showVolume: Bool
    @Binding var indicatorSettings: IndicatorSettings
    @Binding var markLevelFilter: MarkLevelFilter
    var onIndicatorsChange: ((IndicatorSettings) -> Void)?
    var onMarkLevelFilterChange: ((MarkLevelFilter) -> Void)?

    @State private var showSettingsPopover = false
    @State private var showIndicatorPopover = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            // Indicators button
            Button {
                showIndicatorPopover.toggle()
            } label: {
                Label(getIndicatorButtonLabel(), systemImage: "chart.line.uptrend.xyaxis")
            }
            .popover(isPresented: $showIndicatorPopover) {
                IndicatorPopoverView(
                    settings: $indicatorSettings,
                    onSettingsChange: { newSettings in
                        onIndicatorsChange?(newSettings)
                    }
                )
            }

            // Settings button
            Button {
                showSettingsPopover.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showSettingsPopover) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Show Volume", isOn: $showVolume)

                    Divider()

                    Text("Mark Levels")
                        .font(.caption)

                    Toggle(isOn: $markLevelFilter.showInfo) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Info")
                        }
                    }
                    .onChange(of: markLevelFilter.showInfo) { _, _ in
                        onMarkLevelFilterChange?(markLevelFilter)
                    }

                    Toggle(isOn: $markLevelFilter.showWarning) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("Warning")
                        }
                    }
                    .onChange(of: markLevelFilter.showWarning) { _, _ in
                        onMarkLevelFilterChange?(markLevelFilter)
                    }

                    Toggle(isOn: $markLevelFilter.showError) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                            Text("Error")
                        }
                    }
                    .onChange(of: markLevelFilter.showError) { _, _ in
                        onMarkLevelFilterChange?(markLevelFilter)
                    }
                }
                .padding()
                .frame(minWidth: 180)
            }
        }
    }

    func getIndicatorButtonLabel() -> String {
        if indicatorSettings.enabledIndicators.isEmpty {
            return "Indicators"
        } else {
            return "Indicators (\(indicatorSettings.enabledIndicators.count))"
        }
    }
}
