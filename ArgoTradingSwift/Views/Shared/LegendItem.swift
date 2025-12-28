//
//  LegendItem.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

/// Reusable legend item component for displaying labeled values
struct LegendItem: View {
    let label: String
    let value: Double
    let color: Color
    var decimals: Int = 2

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(decimals)))
                .foregroundStyle(color)
        }
    }
}
