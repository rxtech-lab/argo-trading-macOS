//
//  SchemaPickerItemView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct SchemaPickerItemView: View {
    let schema: Schema
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "checkmark")
                        .opacity(0)
                }
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(schema.name)
                Spacer()
                statusIcon(for: schema.runningStatus)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.1)
                    : (isHovered ? Color.primary.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for status: SchemaRunningStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SchemaPickerItemView(
            schema: Schema(name: "My Strategy Config", strategyPath: "strategy.wasm", runningStatus: .idle),
            isSelected: true,
            onSelect: {}
        )
        SchemaPickerItemView(
            schema: Schema(name: "Backtest Config", strategyPath: "backtest.wasm", runningStatus: .completed),
            isSelected: false,
            onSelect: {}
        )
        SchemaPickerItemView(
            schema: Schema(name: "Running Config", strategyPath: "running.wasm", runningStatus: .running),
            isSelected: false,
            onSelect: {}
        )
        SchemaPickerItemView(
            schema: Schema(name: "Failed Config", strategyPath: "failed.wasm", runningStatus: .failed),
            isSelected: false,
            onSelect: {}
        )
    }
    .frame(width: 280)
    .padding()
}
