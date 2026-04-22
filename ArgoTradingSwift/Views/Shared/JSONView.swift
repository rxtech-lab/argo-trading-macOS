//
//  JSONView.swift
//  ArgoTradingSwift
//

import SwiftUI

/// Renders an arbitrary `YAMLValue` object as a form with property names as
/// labels on the left and their values on the right. Nested objects and arrays
/// expand inline as disclosure groups.
struct JSONView: View {
    let object: [String: YAMLValue]

    init(object: [String: YAMLValue]) {
        self.object = object
    }

    init(value: YAMLValue) {
        if case .object(let dict) = value {
            self.object = dict
        } else {
            self.object = [:]
        }
    }

    var body: some View {
        Form {
            if object.isEmpty {
                Text("No values")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(object.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                    JSONRow(key: entry.key, value: entry.value)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct JSONRow: View {
    let key: String
    let value: YAMLValue

    var body: some View {
        switch value {
        case .object(let dict):
            DisclosureGroup(key) {
                ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                    JSONRow(key: entry.key, value: entry.value)
                }
            }
        case .array(let items):
            DisclosureGroup("\(key) [\(items.count)]") {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    JSONRow(key: "[\(index)]", value: item)
                }
            }
        default:
            LabeledContent(key) {
                Text(value.displayString)
                    .foregroundStyle(value.isNull ? .secondary : .primary)
                    .textSelection(.enabled)
            }
        }
    }
}

private extension YAMLValue {
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

#Preview {
    JSONView(object: [
        "initial_capital": .int(100000),
        "broker": .string("interactive_broker"),
        "start_time": .string("2020-01-01T05:35:36Z"),
        "end_time": .string("2025-04-21T05:35:36Z"),
        "decimal_precision": .int(5),
        "market_data_cache_size": .int(10000),
        "portfolio_calculation": .string("average_cost"),
        "nested": .object([
            "flag": .bool(true),
            "ratio": .double(0.25),
        ]),
    ])
    .frame(width: 520, height: 520)
}
