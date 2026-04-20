//
//  RowDetailSheet.swift
//  ArgoTradingSwift
//

import SwiftUI

struct RowDetailField: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var isLong: Bool = false
}

struct RowDetailSheet: View {
    let title: String
    let subtitle: String?
    let fields: [RowDetailField]

    @Environment(\.dismiss) private var dismiss

    init(title: String, subtitle: String? = nil, fields: [RowDetailField]) {
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            Form {
                if !shortFields.isEmpty {
                    Section {
                        ForEach(shortFields) { field in
                            LabeledContent(field.label) {
                                Text(field.value.isEmpty ? "—" : field.value)
                                    .textSelection(.enabled)
                                    .foregroundStyle(field.value.isEmpty ? .secondary : .primary)
                            }
                        }
                    }
                }

                ForEach(longFields) { field in
                    Section(field.label) {
                        Text(field.value.isEmpty ? "—" : field.value)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(field.value.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 520, minHeight: 420)
    }

    private var shortFields: [RowDetailField] { fields.filter { !$0.isLong } }
    private var longFields: [RowDetailField] { fields.filter { $0.isLong } }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

#Preview {
    RowDetailSheet(
        title: "BUY BTCUSDT",
        subtitle: "Jan 10, 2025, 7:40 AM",
        fields: [
            .init(label: "Order ID", value: "abc-123"),
            .init(label: "Symbol", value: "BTCUSDT"),
            .init(label: "Side", value: "BUY"),
            .init(label: "Quantity", value: "0.1000"),
            .init(label: "Price", value: "92266.03"),
            .init(label: "Reason", value: "strategy", isLong: true),
            .init(label: "Message", value: "BUY: RSI bounce 37.3->49.9, close above EMA, vol spike confirmed", isLong: true),
        ]
    )
}
