//
//  SchemaEditorView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import ArgoTrading
import JSONSchema
import JSONSchemaForm
import SwiftUI

struct SchemaEditorView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(SchemaService.self) var schemaService
    @Environment(StrategyService.self) var strategyService
    @Environment(\.dismiss) var dismiss

    let isEditing: Bool
    let existingSchema: Schema?

    @State private var name: String = ""
    @State private var selectedStrategyURL: URL?
    @State private var strategyMetadata: SwiftargoStrategyMetadata?
    @State private var jsonSchema: JSONSchema?
    @State private var formData: FormData = .object(properties: [:])
    @State private var isLoadingMetadata = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    TextField("Schema Name", text: $name)

                    Picker("Strategy", selection: $selectedStrategyURL) {
                        Text("Select a strategy").tag(nil as URL?)
                        ForEach(strategyService.strategyFiles, id: \.self) { file in
                            Text(file.deletingPathExtension().lastPathComponent)
                                .tag(file as URL?)
                        }
                    }
                }

                if isLoadingMetadata {
                    Section("Parameters") {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading strategy parameters...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let schema = jsonSchema {
                    Section("Parameters") {
                        JSONSchemaForm(
                            schema: schema,
                            formData: $formData,
                            showSubmitButton: false
                        )
                    }
                } else if selectedStrategyURL != nil && error == nil {
                    Section("Parameters") {
                        Text("Could not load strategy parameters")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Schema" : "Create Schema")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        schemaService.dismissEditor()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveSchema()
                    }
                    .disabled(name.isEmpty || selectedStrategyURL == nil)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if isEditing, let schema = existingSchema {
                name = schema.name
                selectedStrategyURL = strategyService.strategyFiles.first {
                    $0.lastPathComponent == schema.strategyPath ||
                        $0.path.hasSuffix(schema.strategyPath)
                }
                if let dict = try? JSONSerialization.jsonObject(with: schema.parameters) {
                    formData = formDataFromAny(dict)
                }
            }
        }
        .onChange(of: selectedStrategyURL) { _, newURL in
            loadStrategyMetadata(from: newURL)
        }
    }

    private func loadStrategyMetadata(from url: URL?) {
        guard let url else {
            strategyMetadata = nil
            jsonSchema = nil
            return
        }

        isLoadingMetadata = true
        error = nil

        Task.detached {
            do {
                let strategy = SwiftargoStrategyApi()
                var absolutePath = url.absoluteString
                absolutePath.replace("file://", with: "")
                let metadata = try strategy?.getStrategyMetadata(absolutePath)

                await MainActor.run {
                    strategyMetadata = metadata
                    if let schemaString = metadata?.schema {
                        jsonSchema = try? JSONSchema(jsonString: schemaString)
                    }
                    isLoadingMetadata = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoadingMetadata = false
                }
            }
        }
    }

    private func saveSchema() {
        guard let strategyURL = selectedStrategyURL else { return }

        do {
            let dict = formData.toDictionary() ?? [:]
            let parametersData = try JSONSerialization.data(withJSONObject: dict)
            let strategyPath = strategyURL.lastPathComponent

            if isEditing, let existing = existingSchema {
                var updated = existing
                updated.name = name
                updated.strategyPath = strategyPath
                updated.parameters = parametersData
                updated.updatedAt = Date()
                document.updateSchema(updated)
            } else {
                let schema = Schema(
                    name: name,
                    parameters: parametersData,
                    strategyPath: strategyPath
                )
                document.addSchema(schema)
            }
            schemaService.dismissEditor()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func formDataFromAny(_ value: Any) -> FormData {
        switch value {
        case let dict as [String: Any]:
            var properties: [String: FormData] = [:]
            for (key, val) in dict {
                properties[key] = formDataFromAny(val)
            }
            return .object(properties: properties)
        case let array as [Any]:
            return .array(items: array.map { formDataFromAny($0) })
        case let string as String:
            return .string(string)
        case let number as Double:
            return .number(number)
        case let number as Int:
            return .number(Double(number))
        case let bool as Bool:
            return .boolean(bool)
        default:
            return .null
        }
    }
}

#Preview("Create") {
    SchemaEditorView(
        document: .constant(ArgoTradingDocument()),
        isEditing: false,
        existingSchema: nil
    )
    .environment(SchemaService())
    .environment(StrategyService())
}

#Preview("Edit") {
    SchemaEditorView(
        document: .constant(ArgoTradingDocument()),
        isEditing: true,
        existingSchema: Schema(name: "Test Schema", strategyPath: "test.wasm")
    )
    .environment(SchemaService())
    .environment(StrategyService())
}
