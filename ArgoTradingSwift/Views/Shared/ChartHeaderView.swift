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

    // Overlay visibility toggle (optional - only needed when chart has trade overlays)
    var showTrades: Binding<Bool>?
    var hasTradeOverlays: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            // Trade visibility toggle
            if hasTradeOverlays, let showTrades = showTrades {
                Toggle(isOn: showTrades) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(showTrades.wrappedValue ? .accentColor : .secondary)
                .help("Show/Hide Trades")

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
