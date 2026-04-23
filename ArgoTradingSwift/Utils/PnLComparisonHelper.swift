//
//  PnLComparisonHelper.swift
//  ArgoTradingSwift
//

import SwiftUI

enum PnLComparisonZone: Int, CaseIterable {
    case muchWorse = 0
    case worse = 1
    case matched = 2
    case better = 3
    case muchBetter = 4

    var color: Color {
        switch self {
        case .muchWorse: return .red
        case .worse: return .orange
        case .matched: return .gray
        case .better: return .green
        case .muchBetter: return .blue
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .muchWorse: return "Much Worse"
        case .worse: return "Underperforming"
        case .matched: return "On Par"
        case .better: return "Outperforming"
        case .muchBetter: return "Strong Alpha"
        }
    }

    static func zone(totalPnl: Double, buyAndHoldPnl: Double) -> PnLComparisonZone {
        let denom = max(abs(buyAndHoldPnl), 1.0)
        let ratio = (totalPnl - buyAndHoldPnl) / denom
        if ratio < -0.5 { return .muchWorse }
        if ratio < -0.1 { return .worse }
        if ratio <= 0.1 { return .matched }
        if ratio <= 0.5 { return .better }
        return .muchBetter
    }
}

private struct PnLComparisonBars: View {
    let totalPnl: Double
    let buyAndHoldPnl: Double

    private var maxMagnitude: Double {
        max(abs(totalPnl), abs(buyAndHoldPnl), 1.0)
    }

    private var hasNegative: Bool {
        totalPnl < 0 || buyAndHoldPnl < 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PnLBar(
                label: "Strategy",
                value: totalPnl,
                maxMagnitude: maxMagnitude,
                showCenterAxis: hasNegative
            )
            PnLBar(
                label: "Buy & Hold",
                value: buyAndHoldPnl,
                maxMagnitude: maxMagnitude,
                showCenterAxis: hasNegative
            )
        }
    }
}

private struct PnLBar: View {
    let label: LocalizedStringKey
    let value: Double
    let maxMagnitude: Double
    let showCenterAxis: Bool

    private var barColor: Color { value >= 0 ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(value))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                let width = geo.size.width
                let axis: CGFloat = showCenterAxis ? width / 2 : 0
                let available = showCenterAxis ? width / 2 : width
                let barWidth = min(abs(value) / maxMagnitude * available, available)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    if showCenterAxis {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 1, height: 10)
                            .offset(x: axis - 0.5, y: -2)
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: barWidth, height: 6)
                        .offset(x: value >= 0 ? axis : axis - barWidth)
                }
            }
            .frame(height: 10)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

enum PnLComparisonHelper {
    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func helpText(totalPnl: Double, buyAndHoldPnl: Double) -> LocalizedStringKey {
        let zone = PnLComparisonZone.zone(totalPnl: totalPnl, buyAndHoldPnl: buyAndHoldPnl)
        let formattedDelta = formatCurrency(abs(totalPnl - buyAndHoldPnl))

        switch zone {
        case .muchWorse:
            return "Total Profit and Loss across all trades — realized PnL plus unrealized PnL on any open positions.\n\nThe strategy significantly underperformed buy-and-hold by \(formattedDelta). Passive holding would have produced a far better outcome over this period."
        case .worse:
            return "Total Profit and Loss across all trades — realized PnL plus unrealized PnL on any open positions.\n\nThe strategy underperformed buy-and-hold by \(formattedDelta). Consider whether active trading is justified versus simply holding."
        case .matched:
            return "Total Profit and Loss across all trades — realized PnL plus unrealized PnL on any open positions.\n\nResults are close to buy-and-hold (difference: \(formattedDelta)). Make sure the active-trading overhead — fees, slippage, effort — is worth it."
        case .better:
            return "Total Profit and Loss across all trades — realized PnL plus unrealized PnL on any open positions.\n\nThe strategy outperformed buy-and-hold by \(formattedDelta). The strategy is adding value over passive holding."
        case .muchBetter:
            return "Total Profit and Loss across all trades — realized PnL plus unrealized PnL on any open positions.\n\nThe strategy significantly outperformed buy-and-hold by \(formattedDelta). Strong alpha — verify this isn't due to a single lucky period or overfitting."
        }
    }

    @ViewBuilder
    static func helpView(totalPnl: Double, buyAndHoldPnl: Double) -> some View {
        let zone = PnLComparisonZone.zone(totalPnl: totalPnl, buyAndHoldPnl: buyAndHoldPnl)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(zone.color)
                    .frame(width: 8, height: 8)
                Text(zone.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(zone.color)
            }
            PnLComparisonBars(totalPnl: totalPnl, buyAndHoldPnl: buyAndHoldPnl)
            Text(helpText(totalPnl: totalPnl, buyAndHoldPnl: buyAndHoldPnl))
                .font(.callout)
        }
        .padding()
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}
