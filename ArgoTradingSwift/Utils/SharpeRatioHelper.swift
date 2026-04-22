//
//  SharpeRatioHelper.swift
//  ArgoTradingSwift
//

import SwiftUI

enum SharpeRatioZone: Int, CaseIterable {
    case negative = 0
    case suboptimal = 1
    case acceptable = 2
    case good = 3
    case excellent = 4

    var color: Color {
        switch self {
        case .negative: return .red
        case .suboptimal: return .orange
        case .acceptable: return .yellow
        case .good: return .green
        case .excellent: return .blue
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .negative: return "Negative"
        case .suboptimal: return "Suboptimal"
        case .acceptable: return "Acceptable"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }

    static func zone(for value: Double) -> SharpeRatioZone {
        if value < 0 {
            return .negative
        } else if value < 1.0 {
            return .suboptimal
        } else if value < 2.0 {
            return .acceptable
        } else if value < 3.0 {
            return .good
        } else {
            return .excellent
        }
    }
}

struct SharpeRatioZoneIndicator: View {
    let value: Double

    private var currentZone: SharpeRatioZone {
        SharpeRatioZone.zone(for: value)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(SharpeRatioZone.allCases, id: \.rawValue) { zone in
                    ZoneSegment(zone: zone, isActive: zone == currentZone)
                }
            }
            .frame(height: 24)

            HStack(spacing: 2) {
                ForEach(SharpeRatioZone.allCases, id: \.rawValue) { zone in
                    ZoneArrow(isActive: zone == currentZone, activeWidth: 80, inactiveWidth: 24)
                }
            }
            .frame(height: 10)
        }
    }
}

private struct ZoneSegment: View {
    let zone: SharpeRatioZone
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(zone.color.opacity(isActive ? 1.0 : 0.3))
                .frame(width: isActive ? 80 : 24)

            if isActive {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                    Text(zone.label)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(zone == .acceptable || zone == .excellent ? .black : .white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private struct ZoneArrow: View {
    let isActive: Bool
    let activeWidth: CGFloat
    let inactiveWidth: CGFloat

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: isActive ? activeWidth : inactiveWidth)

            if isActive {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.primary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

#Preview("Zone Indicator - Negative") {
    SharpeRatioZoneIndicator(value: -0.5)
        .padding()
}

#Preview("Zone Indicator - Suboptimal") {
    SharpeRatioZoneIndicator(value: 0.5)
        .padding()
}

#Preview("Zone Indicator - Acceptable") {
    SharpeRatioZoneIndicator(value: 1.5)
        .padding()
}

#Preview("Zone Indicator - Good") {
    SharpeRatioZoneIndicator(value: 2.5)
        .padding()
}

#Preview("Zone Indicator - Excellent") {
    SharpeRatioZoneIndicator(value: 3.5)
        .padding()
}

enum SharpeRatioHelper {
    static func helpText(for value: Double) -> LocalizedStringKey {
        let formattedValue = String(format: "%.2f", value)

        if value < 0 {
            return "The Sharpe Ratio measures risk-adjusted return. It shows how much excess return you receive for the extra volatility of holding a riskier asset.\n\nA negative ratio (\(formattedValue)) indicates the strategy is underperforming the risk-free rate. Consider reviewing the strategy's risk management."
        } else if value < 1.0 {
            return "The Sharpe Ratio measures risk-adjusted return. It shows how much excess return you receive for the extra volatility of holding a riskier asset.\n\nA ratio below 1.0 (\(formattedValue)) suggests suboptimal risk-adjusted returns. The returns may not adequately compensate for the risk taken."
        } else if value < 2.0 {
            return "The Sharpe Ratio measures risk-adjusted return. It shows how much excess return you receive for the extra volatility of holding a riskier asset.\n\nA ratio between 1.0-2.0 (\(formattedValue)) indicates acceptable risk-adjusted performance. This is considered decent for most strategies."
        } else if value < 3.0 {
            return "The Sharpe Ratio measures risk-adjusted return. It shows how much excess return you receive for the extra volatility of holding a riskier asset.\n\nA ratio between 2.0-3.0 (\(formattedValue)) indicates very good risk-adjusted performance. The strategy is generating strong returns relative to its risk."
        } else {
            return "The Sharpe Ratio measures risk-adjusted return. It shows how much excess return you receive for the extra volatility of holding a riskier asset.\n\nA ratio above 3.0 (\(formattedValue)) indicates excellent risk-adjusted performance. This is exceptional, but verify it's sustainable and not due to overfitting."
        }
    }

    @ViewBuilder
    static func helpView(for value: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SharpeRatioZoneIndicator(value: value)

            Text(helpText(for: value))
                .font(.callout)
        }
        .padding()
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}
