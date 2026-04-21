//
//  StrategyParametersView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import JSONSchema
import JSONSchemaForm
import LightweightChart
import SwiftUI
import Translation

struct StrategyParametersView: View {
    let jsonSchema: String

    @State private var translatedSchemaString: String?
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var isTranslating: Bool = true

    private var resolvedSchema: JSONSchema? {
        guard let source = translatedSchemaString else { return nil }
        return try? JSONSchema(jsonString: source)
    }

    var body: some View {
        Group {
            if isTranslating {
                ProgressView {
                    Text("Translating…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let schema = resolvedSchema {
                Form {
                    JSONSchemaForm(schema: schema, formData: .constant(.object(properties: [:])), showSubmitButton: false)
                }
                .formStyle(.grouped)
                .disabled(true)
            } else {
                Text("Invalid JSON Schema")
            }
        }
        .onAppear {
            if translationConfig == nil {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: LocaleHelper.preferredTargetLanguage()
                )
            }
        }
        .onChange(of: jsonSchema) { _, _ in
            translatedSchemaString = nil
            isTranslating = true
            if translationConfig != nil {
                translationConfig?.invalidate()
            } else {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: LocaleHelper.preferredTargetLanguage()
                )
            }
        }
        .translationTask(translationConfig) { session in
            let result = await SchemaTranslator.translate(jsonString: jsonSchema, session: session)
            translatedSchemaString = result
            isTranslating = false
        }
    }
}
