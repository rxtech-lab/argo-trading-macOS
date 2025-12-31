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
    @Binding var zoomScale: CGFloat
    let minZoom: CGFloat
    let maxZoom: CGFloat

    // Overlay visibility toggles (optional - only needed when chart has overlays)
    var showTrades: Binding<Bool>?
    var showMarks: Binding<Bool>?
    var hasTradeOverlays: Bool = false
    var hasMarkOverlays: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            // Overlay visibility toggles
            if hasTradeOverlays || hasMarkOverlays {
                HStack(spacing: 8) {
                    if hasTradeOverlays, let showTrades = showTrades {
                        Toggle(isOn: showTrades) {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(showTrades.wrappedValue ? .accentColor : .secondary)
                        .help("Show/Hide Trades")
                    }

                    if hasMarkOverlays, let showMarks = showMarks {
                        Toggle(isOn: showMarks) {
                            Image(systemName: "mappin")
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .tint(showMarks.wrappedValue ? .accentColor : .secondary)
                        .help("Show/Hide Marks")
                    }
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 8)
            }

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        zoomScale = max(minZoom, zoomScale / 1.5)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption)
                    .frame(width: 40)

                Button {
                    withAnimation {
                        zoomScale = min(maxZoom, zoomScale * 1.5)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Button {
                    withAnimation {
                        zoomScale = 1.0
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(zoomScale == 1.0)
            }
        }
    }
}
