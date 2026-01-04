//
//  ChartHeaderView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Reusable chart header with title and zoom controls
struct ChartHeaderView: View {
    let title: String
    @Binding var showVolume: Bool
    @Binding var indicatorSettings: IndicatorSettings
    var onIndicatorsChange: ((IndicatorSettings) -> Void)?
    
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
                }
                .padding()
                .frame(minWidth: 150)
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
