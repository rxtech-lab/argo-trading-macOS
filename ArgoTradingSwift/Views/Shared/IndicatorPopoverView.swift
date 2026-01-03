//
//  IndicatorPopoverView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/3/26.
//

import SwiftUI

/// Popover view for configuring technical indicators
struct IndicatorPopoverView: View {
    @Binding var settings: IndicatorSettings
    var onSettingsChange: ((IndicatorSettings) -> Void)?

    var body: some View {
        ScrollView {
            HStack {
                Text("Technical Indicators")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 12)

            Divider()
                .padding(.bottom, 8)

            ForEach($settings.indicators) { $indicator in
                IndicatorRowView(config: $indicator) {
                    onSettingsChange?(settings)
                }
                Divider()
                    .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)
        }
        .frame(idealWidth: 300, maxHeight: 350,)
        .padding()
    }
}

/// Single indicator row with toggle and parameter configuration
struct IndicatorRowView: View {
    @Binding var config: IndicatorConfig
    var onChange: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: config.type.systemImage)
                    .foregroundStyle(config.isEnabled ? Color(hex: config.color) ?? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.type.displayName)
                        .font(.body)

                    if config.isEnabled && !config.parameters.isEmpty {
                        Text(parameterSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if config.isEnabled && !config.parameters.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Toggle("", isOn: $config.isEnabled)
                    .labelsHidden()
                    .onChange(of: config.isEnabled) { _, _ in
                        onChange?()
                    }
            }

            if isExpanded && config.isEnabled {
                VStack(spacing: 8) {
                    ForEach(Array(config.parameters.keys.sorted()), id: \.self) { key in
                        IndicatorParameterRow(
                            label: parameterDisplayName(key),
                            value: Binding(
                                get: { config.parameters[key] ?? 0 },
                                set: { newValue in
                                    config.parameters[key] = newValue
                                    onChange?()
                                }
                            )
                        )
                    }
                }
                .padding(.leading, 32)
                .padding(.top, 4)
            }
        }
    }

    private var parameterSummary: String {
        config.parameters.sorted(by: { $0.key < $1.key })
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    private func parameterDisplayName(_ key: String) -> String {
        switch key {
        case "period": return "Period"
        case "fastPeriod": return "Fast Period"
        case "slowPeriod": return "Slow Period"
        case "signalPeriod": return "Signal Period"
        default: return key.capitalized
        }
    }
}

/// Parameter input row with stepper
struct IndicatorParameterRow: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    if value > 1 { value -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .disabled(value <= 1)

                Text("\(value)")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 30)

                Button {
                    if value < 200 { value += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .disabled(value >= 200)
            }
        }
    }
}

#Preview {
    IndicatorPopoverView(
        settings: .constant(.default)
    )
}
