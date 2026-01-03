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
    @Binding var enabledIndicators: Set<ChartIndicator>
    let isLoading: Bool
    var onIntervalChange: ((ChartTimeInterval) -> Void)?
    var onIndicatorToggle: ((ChartIndicator, Bool) -> Void)?

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
                    if !enabledIndicators.isEmpty {
                        Text("(\(enabledIndicators.count))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.bordered)
            .popover(isPresented: $showIndicatorPopover) {
                IndicatorSelectionPopover(
                    enabledIndicators: $enabledIndicators,
                    onIndicatorToggle: onIndicatorToggle
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

/// Popover content for selecting chart indicators
struct IndicatorSelectionPopover: View {
    @Binding var enabledIndicators: Set<ChartIndicator>
    var onIndicatorToggle: ((ChartIndicator, Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Technical Indicators")
                    .font(.headline)
                Spacer()
                if !enabledIndicators.isEmpty {
                    Button("Clear All") {
                        for indicator in enabledIndicators {
                            onIndicatorToggle?(indicator, false)
                        }
                        enabledIndicators.removeAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Indicator list grouped by type
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Moving Averages
                    IndicatorGroupView(
                        title: "Moving Averages",
                        indicators: [.sma20, .sma50, .sma200, .ema12, .ema26],
                        enabledIndicators: $enabledIndicators,
                        onIndicatorToggle: onIndicatorToggle
                    )

                    Divider()

                    // Volatility
                    IndicatorGroupView(
                        title: "Volatility",
                        indicators: [.bollingerBands],
                        enabledIndicators: $enabledIndicators,
                        onIndicatorToggle: onIndicatorToggle
                    )

                    Divider()

                    // Oscillators
                    IndicatorGroupView(
                        title: "Oscillators",
                        indicators: [.rsi, .macd],
                        enabledIndicators: $enabledIndicators,
                        onIndicatorToggle: onIndicatorToggle
                    )

                    Divider()

                    // Volume
                    IndicatorGroupView(
                        title: "Volume",
                        indicators: [.volume],
                        enabledIndicators: $enabledIndicators,
                        onIndicatorToggle: onIndicatorToggle
                    )
                }
                .padding(16)
            }
        }
        .frame(width: 280, height: 400)
    }
}

/// A group of indicators with a title
struct IndicatorGroupView: View {
    let title: String
    let indicators: [ChartIndicator]
    @Binding var enabledIndicators: Set<ChartIndicator>
    var onIndicatorToggle: ((ChartIndicator, Bool) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(indicators) { indicator in
                IndicatorRowView(
                    indicator: indicator,
                    isEnabled: enabledIndicators.contains(indicator),
                    onToggle: { isEnabled in
                        if isEnabled {
                            enabledIndicators.insert(indicator)
                        } else {
                            enabledIndicators.remove(indicator)
                        }
                        onIndicatorToggle?(indicator, isEnabled)
                    }
                )
            }
        }
    }
}

/// A single indicator row with toggle
struct IndicatorRowView: View {
    let indicator: ChartIndicator
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isEnabled)
        } label: {
            HStack(spacing: 10) {
                // Color indicator
                Circle()
                    .fill(Color(hex: indicator.color) ?? .gray)
                    .frame(width: 8, height: 8)

                // Icon
                Image(systemName: indicator.systemImage)
                    .frame(width: 16)
                    .foregroundStyle(.secondary)

                // Name
                Text(indicator.displayName)
                    .foregroundStyle(.primary)

                Spacer()

                // Checkbox
                Image(systemName: isEnabled ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isEnabled ? .blue : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
