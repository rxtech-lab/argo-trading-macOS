//
//  ChartMarkerTooltip.swift
//  LightweightChart
//
//  Native SwiftUI tooltip for chart markers
//

import SwiftUI

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r, g, b, a: Double
        switch hexSanitized.count {
        case 6:
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

/// Native SwiftUI tooltip for displaying marker information on hover
public struct ChartMarkerTooltip: View {
    public let data: JSMarkerHoverData

    public init(data: JSMarkerHoverData) {
        self.data = data
    }

    public var body: some View {
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

            if let level = marker.level, !level.isEmpty {
                TooltipRow(
                    label: "Level",
                    value: level,
                    valueColor: levelColor(level)
                )
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

    private func levelColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "ERROR": return .red
        case "WARNING": return .orange
        default: return Color(white: 0.9)
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
