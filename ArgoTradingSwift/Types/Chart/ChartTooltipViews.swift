//
//  ChartTooltipViews.swift
//  ArgoTradingSwift
//
//  Tooltip views for chart overlays (trades and marks)
//

import SwiftUI

// MARK: - Trade Tooltip View

struct TradeTooltipView: View {
    let trade: Trade

    private var isBuy: Bool {
        trade.side == .buy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isBuy ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .foregroundColor(isBuy ? .green : .red)
                Text(trade.side.rawValue.uppercased())
                    .font(.caption.bold())
            }

            Divider()

            LabeledContent("Symbol", value: trade.symbol)
            LabeledContent("Position", value: trade.positionType)
            if let date = trade.executedAt {
                LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .standard))
            }
            LabeledContent("Qty", value: String(format: "%.4f", trade.executedQty))
            LabeledContent("Price", value: String(format: "%.2f", trade.executedPrice))
            if trade.side == .sell {
                LabeledContent("PnL", value: String(format: "%.2f", trade.pnl))
                    .foregroundColor(trade.pnl >= 0 ? .green : .red)
            }

            if !trade.reason.isEmpty {
                Divider()
                Text(trade.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(8)
        .glassEffect(in: .rect(cornerRadius: 12))
        .frame(maxWidth: 200)
    }
}

// MARK: - Mark Tooltip View

struct MarkTooltipView: View {
    let mark: Mark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                markIcon
                Text(mark.title)
                    .font(.caption.bold())
            }

            if !mark.category.isEmpty {
                Text(mark.category)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !mark.message.isEmpty {
                Divider()
                Text("Message:")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(mark.message)
                    .font(.caption2)
            }

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Signal: \(mark.signal.type.rawValue)")
                    .font(.caption2)
                if !mark.signal.reason.isEmpty {
                    Text(mark.signal.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: 200)
    }

    @ViewBuilder
    private var markIcon: some View {
        let color = mark.color.toColor()

        switch mark.shape {
        case .circle:
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
        case .square:
            Rectangle()
                .fill(color)
                .frame(width: 10, height: 10)
        case .triangle:
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(color)
        }
    }
}
