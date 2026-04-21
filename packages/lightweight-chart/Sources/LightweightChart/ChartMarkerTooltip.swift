//
//  ChartMarkerTooltip.swift
//  LightweightChart
//
//  Native SwiftUI tooltip for chart markers
//

import SwiftUI
import Translation

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

    @State private var translations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?

    private var translatableValues: [(key: String, text: String)] {
        var out: [(String, String)] = []
        if let reason = marker.reason, !reason.isEmpty { out.append(("reason", reason)) }
        if let message = marker.message, !message.isEmpty { out.append(("message", message)) }
        return out
    }

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

            // PnL
            if let pnl = marker.pnl {
                if isBuy && pnl == 0 {
                    TooltipRow(label: "PnL", value: "-")
                } else {
                    TooltipRow(
                        label: "PnL",
                        value: formatNumber(pnl, decimals: 2),
                        valueColor: pnl >= 0 ? (Color(hex: "#32d74b") ?? .green) : (Color(hex: "#ff453a") ?? .red)
                    )
                }
            }

            // Cumulative PnL
            if let cumulativePnl = marker.cumulativePnl {
                TooltipRow(
                    label: "Cum. PnL",
                    value: formatNumber(cumulativePnl, decimals: 2),
                    valueColor: cumulativePnl >= 0 ? (Color(hex: "#32d74b") ?? .green) : (Color(hex: "#ff453a") ?? .red)
                )
            }

            // Open Position Qty
            if let openPositionQty = marker.openPositionQty {
                TooltipRow(label: "Open Pos Qty", value: formatNumber(openPositionQty, decimals: 4))
            }

            // Balance
            if let balance = marker.balance {
                TooltipRow(label: "Balance", value: formatNumber(balance, decimals: 2))
            }

            // Hold Time (skip when 0 — opening trades don't have a hold time)
            if let holdTime = marker.holdTime, holdTime != 0 {
                TooltipRow(label: "Hold Time", value: formatHoldTime(holdTime))
            }

            // Reason
            if let reason = marker.reason, !reason.isEmpty {
                TranslatedCaption(
                    label: "Reason:",
                    original: reason,
                    translated: translations["reason"]
                )
                .padding(.top, 8)
            }

            // Message
            if let message = marker.message, !message.isEmpty {
                TranslatedCaption(
                    label: "Message:",
                    original: message,
                    translated: translations["message"]
                )
                .padding(.top, (marker.reason?.isEmpty ?? true) ? 8 : 4)
            }
        }
        .onAppear {
            if translationConfig == nil, !translatableValues.isEmpty {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: LocaleHelper.preferredTargetLanguage()
                )
            }
        }
        .translationTask(translationConfig) { session in
            let items = translatableValues
            let map = await translateBatch(session: session, items: items)
            translations = map
        }
    }
}

/// Caption row that shows the original reason/message and a translated copy
/// underneath when the system Translation framework produced a different result.
private struct TranslatedCaption: View {
    let label: LocalizedStringKey
    let original: String
    let translated: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Text(label)) \(original)")
                .font(.system(size: 11))
                .italic()
                .foregroundColor(Color(white: 0.56))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let translated, !translated.isEmpty, translated != original {
                Text(translated)
                    .font(.system(size: 11))
                    .italic()
                    .foregroundColor(Color(white: 0.72))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Mark Marker Section

private struct MarkMarkerSection: View {
    let marker: JSMarkerInfo

    @State private var translations: [String: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?

    private var translatableValues: [(key: String, text: String)] {
        var out: [(String, String)] = []
        if let message = marker.message, !message.isEmpty { out.append(("message", message)) }
        if let signalReason = marker.signalReason, !signalReason.isEmpty { out.append(("signalReason", signalReason)) }
        return out
    }

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
                TranslatedCaption(
                    label: "Message:",
                    original: message,
                    translated: translations["message"]
                )
                .padding(.top, 8)
            }

            // Signal reason
            if let signalReason = marker.signalReason, !signalReason.isEmpty {
                TranslatedCaption(
                    label: "Reason:",
                    original: signalReason,
                    translated: translations["signalReason"]
                )
                .padding(.top, marker.message == nil ? 8 : 4)
            }
        }
        .onAppear {
            if translationConfig == nil, !translatableValues.isEmpty {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: LocaleHelper.preferredTargetLanguage()
                )
            }
        }
        .translationTask(translationConfig) { session in
            let items = translatableValues
            let map = await translateBatch(session: session, items: items)
            translations = map
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
    let label: LocalizedStringKey
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

private func formatHoldTime(_ seconds: Double) -> String {
    Duration.seconds(seconds).formatted(
        .units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)
    )
}

private func formatDate(_ timestamp: Double) -> String {
    let date = Date(timeIntervalSince1970: timestamp)
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy, h:mm a"
    formatter.timeZone = .gmt
    return formatter.string(from: date)
}

/// Batches one translation request per item and returns a map keyed by the
/// caller-supplied identifier. Shared between trade and mark tooltip sections
/// so translations go out in a single round-trip instead of per field.
func translateBatch(
    session: TranslationSession,
    items: [(key: String, text: String)]
) async -> [String: String] {
    guard !items.isEmpty else { return [:] }
    let requests = items.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.key) }
    do {
        let responses = try await session.translations(from: requests)
        var map: [String: String] = [:]
        for response in responses {
            guard let key = response.clientIdentifier else { continue }
            map[key] = response.targetText
        }
        return map
    } catch {
        return [:]
    }
}
