//
//  ChartMarkerTooltip.swift
//  ArgoTradingSwift
//
//  Native SwiftUI tooltip for chart markers
//

import SwiftUI

/// Native SwiftUI tooltip for displaying marker information on hover
struct ChartMarkerTooltip: View {
    let data: JSMarkerHoverData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sortedMarkers.enumerated()), id: \.offset) { index, marker in
                if index > 0 {
                    Divider()
                        .background(Color.white.opacity(0.12))
                        .padding(.vertical, 12)
                }

                if marker.markerType == "trade" {
                    TradeMarkerSection(marker: marker)
                } else {
                    MarkMarkerSection(marker: marker)
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private var sortedMarkers: [JSMarkerInfo] {
        // Sort: trades first, then marks
        data.markers.sorted { a, b in
            if a.markerType == "trade" && b.markerType != "trade" { return true }
            if a.markerType != "trade" && b.markerType == "trade" { return false }
            return false
        }
    }
}

// MARK: - Trade Marker Section

private struct TradeMarkerSection: View {
    let marker: JSMarkerInfo

    private var isBuy: Bool { marker.isBuy ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isBuy ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 20, height: 20)

                    Image(systemName: isBuy ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isBuy ? .green : .red)
                }

                Text(isBuy ? "BUY" : "SELL")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("TRADE")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(Color(white: 0.88))
                    .cornerRadius(4)
            }
            .padding(.bottom, 8)

            // Divider
            Divider()
                .padding(.bottom, 4)

            // Details
            TooltipRow(label: "Symbol", value: marker.symbol ?? "-")
            TooltipRow(label: "Position", value: marker.positionType ?? "-")
            TooltipRow(label: "Date", value: formatDate(marker.time))
            TooltipRow(label: "Qty", value: formatNumber(marker.executedQty, decimals: 4))
            TooltipRow(label: "Price", value: formatNumber(marker.executedPrice, decimals: 2))

            // PnL (only for sell)
            if !isBuy, let pnl = marker.pnl {
                TooltipRow(
                    label: "PnL",
                    value: formatNumber(pnl, decimals: 2),
                    valueColor: pnl >= 0 ? (Color(hex: "#32d74b") ?? .green) : (Color(hex: "#ff453a") ?? .red)
                )
            }

            // Reason
            if let reason = marker.reason, !reason.isEmpty {
                Text("Reason: \(reason)")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(Color(white: 0.56))
                    .lineSpacing(2)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Mark Marker Section

private struct MarkMarkerSection: View {
    let marker: JSMarkerInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 10) {
                // Icon
                Circle()
                    .fill(Color(hex: marker.color ?? "#ffc107") ?? .yellow)
                    .frame(width: 8, height: 8)
                    .padding(6)

                Text(marker.title ?? "Mark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("SIGNAL")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((Color(hex: "#ffc107") ?? .yellow).opacity(0.15))
                    .foregroundColor(Color(hex: "#ffc107") ?? .yellow)
                    .cornerRadius(4)
            }
            .padding(.bottom, 8)

            // Details
            if let category = marker.category, !category.isEmpty {
                TooltipRow(label: "Category", value: category)
            }

            if let signalType = marker.signalType, !signalType.isEmpty {
                TooltipRow(label: "Signal", value: signalType)
            }

            // Message
            if let message = marker.message, !message.isEmpty {
                Text("Message: \(message)")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(Color(white: 0.56))
                    .lineSpacing(2)
                    .padding(.top, 8)
            }

            // Signal reason
            if let signalReason = marker.signalReason, !signalReason.isEmpty {
                Text("Reason: \(signalReason)")
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(Color(white: 0.56))
                    .lineSpacing(2)
                    .padding(.top, marker.message == nil ? 8 : 4)
            }
        }
    }
}

// MARK: - Tooltip Row

private struct TooltipRow: View {
    let label: String
    let value: String
    var valueColor: Color = .init(white: 0.9)

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(white: 0.6))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Helpers

private func formatNumber(_ value: Double?, decimals: Int) -> String {
    guard let value else { return "-" }
    return String(format: "%.\(decimals)f", value)
}

private func formatDate(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy, h:mm a"
    return formatter.string(from: date)
}

// MARK: - Preview

#Preview("Trade Marker") {
    ChartMarkerTooltip(data: JSMarkerHoverData(
        markers: [
            JSMarkerInfo(
                markerType: "trade",
                time: Date().timeIntervalSince1970,
                isBuy: true,
                symbol: "BTCUSDT",
                positionType: "LONG",
                executedQty: 0.5,
                executedPrice: 42350.00,
                pnl: nil,
                reason: "RSI oversold signal triggered",
                title: nil,
                color: nil,
                category: nil,
                message: nil,
                signalType: nil,
                signalReason: nil
            )
        ],
        screenX: 100,
        screenY: 100
    ))
    .padding()
    .background(Color.black)
}

#Preview("Sell with PnL") {
    ChartMarkerTooltip(data: JSMarkerHoverData(
        markers: [
            JSMarkerInfo(
                markerType: "trade",
                time: Date().timeIntervalSince1970,
                isBuy: false,
                symbol: "ETHUSDT",
                positionType: "SHORT",
                executedQty: 2.0,
                executedPrice: 2250.50,
                pnl: 125.75,
                reason: "Take profit reached",
                title: nil,
                color: nil,
                category: nil,
                message: nil,
                signalType: nil,
                signalReason: nil
            )
        ],
        screenX: 100,
        screenY: 100
    ))
    .padding()
    .background(Color.black)
}

#Preview("Signal Mark") {
    ChartMarkerTooltip(data: JSMarkerHoverData(
        markers: [
            JSMarkerInfo(
                markerType: "mark",
                time: Date().timeIntervalSince1970,
                isBuy: nil,
                symbol: nil,
                positionType: nil,
                executedQty: nil,
                executedPrice: nil,
                pnl: nil,
                reason: nil,
                title: "RSI Divergence",
                color: "#ffc107",
                category: "Technical",
                message: "Bullish divergence detected",
                signalType: "BUY",
                signalReason: "RSI showing higher lows while price shows lower lows"
            )
        ],
        screenX: 100,
        screenY: 100
    ))
    .padding()
    .background(Color.black)
}
