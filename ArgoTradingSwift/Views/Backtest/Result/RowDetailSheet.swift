//
//  RowDetailSheet.swift
//  ArgoTradingSwift
//

import LightweightChart
import SwiftUI
import Translation

struct RowDetailField: Identifiable {
    let id = UUID()
    let label: LocalizedStringKey
    let value: String
    var isLong: Bool = false
    var translate: Bool = false
    var help: LocalizedStringKey? = nil
}

struct RowDetailSheet: View {
    let title: String
    let subtitle: String?
    let fields: [RowDetailField]

    @Environment(\.dismiss) private var dismiss

    @State private var translations: [UUID: String] = [:]
    @State private var translationConfig: TranslationSession.Configuration?

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
                            if let help = field.help {
                                LabeledContentWithHelp(field.label, help: help) {
                                    Text(field.value.isEmpty ? "—" : field.value)
                                        .textSelection(.enabled)
                                        .foregroundStyle(field.value.isEmpty ? .secondary : .primary)
                                }
                            } else {
                                LabeledContent(field.label) {
                                    Text(field.value.isEmpty ? "—" : field.value)
                                        .textSelection(.enabled)
                                        .foregroundStyle(field.value.isEmpty ? .secondary : .primary)
                                }
                            }
                        }
                    }
                }

                ForEach(longFields) { field in
                    Section(field.label) {
                        longFieldContent(field)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            if translationConfig == nil, !translatableFields.isEmpty {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: LocaleHelper.preferredTargetLanguage()
                )
            }
        }
        .translationTask(translationConfig) { session in
            await runBatchTranslation(session: session)
        }
    }

    @ViewBuilder
    private func longFieldContent(_ field: RowDetailField) -> some View {
        if field.translate, !field.value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(field.value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let translated = translations[field.id], translated != field.value {
                    Text(translated)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } else {
            Text(field.value.isEmpty ? "—" : field.value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(field.value.isEmpty ? .secondary : .primary)
        }
    }

    private var shortFields: [RowDetailField] { fields.filter { !$0.isLong } }
    private var longFields: [RowDetailField] { fields.filter { $0.isLong } }
    private var translatableFields: [RowDetailField] {
        fields.filter { $0.translate && !$0.value.isEmpty }
    }

    private func runBatchTranslation(session: TranslationSession) async {
        let toTranslate = translatableFields
        guard !toTranslate.isEmpty else { return }

        let requests = toTranslate.map { field in
            TranslationSession.Request(sourceText: field.value, clientIdentifier: field.id.uuidString)
        }
        do {
            let responses = try await session.translations(from: requests)
            var map: [UUID: String] = [:]
            for response in responses {
                guard let id = response.clientIdentifier.flatMap(UUID.init(uuidString:)) else { continue }
                map[id] = response.targetText
            }
            translations = map
        } catch {
            translations = [:]
        }
    }

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
            .init(label: "Reason", value: "strategy", isLong: true, translate: true),
            .init(label: "Message", value: "BUY: RSI bounce 37.3->49.9, close above EMA, vol spike confirmed", isLong: true, translate: true),
        ]
    )
}
