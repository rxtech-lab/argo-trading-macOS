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
    @Environment(BacktestService.self) var backtestService
    @Environment(AlertManager.self) var alertManager
    @Environment(StrategyCacheService.self) var strategyCacheService
    @Environment(KeychainService.self) var keychainService

    let isEditing: Bool
    let existingSchema: Schema?

    @State private var name: String = ""
    @State private var selectedStrategyURL: URL?
    @State private var strategyMetadata: SwiftargoStrategyMetadata?
    @State private var strategySchema: JSONSchema?
    @State private var backtestSchema: JSONSchema?
    @State private var strategyFormData: FormData = .object(properties: [:])
    @State private var backtestFormData: FormData = .object(properties: [:])
    @State private var isLoadingMetadata = false
    @State private var strategyError: String?
    @State private var backtestError: String?
    @State private var strategyController = JSONSchemaFormController()
    @State private var backtestController = JSONSchemaFormController()

    @State private var keychainFieldNames: Set<String> = []
    @State private var keychainUiSchema: [String: Any]?
    @State private var rawSchemaString: String?

    var body: some View {
        TabView {
            Tab("Backtest", systemImage: "list.bullet.clipboard.fill") {
                buildBacktestView()
            }
            Tab("Strategy", systemImage: "app.fill") {
                buildStrategyView()
            }

        }.tabViewStyle(.sidebarAdaptable)
            .alertManager(alertManager)
            .frame(minWidth: 600, minHeight: 700)
            .onAppear {
                // Load backtest engine schema
                do {
                    let schemaString = try backtestService.getBacktestEngineConfigSchema()
                    backtestSchema = try JSONSchema(jsonString: schemaString)
                } catch {
                    print("Failed to load backtest schema: \(error)")
                    self.backtestError = error.localizedDescription
                }

                if isEditing, let schema = existingSchema {
                    name = schema.name
                    selectedStrategyURL = strategyService.strategyFiles.first {
                        $0.lastPathComponent == schema.strategyPath ||
                            $0.path.hasSuffix(schema.strategyPath)
                    }
                    if let dict = try? JSONSerialization.jsonObject(with: schema.parameters) {
                        strategyFormData = formDataFromAny(dict)
                    }
                    if let dict = try? JSONSerialization.jsonObject(with: schema.backtestEngineConfig) {
                        backtestFormData = formDataFromAny(dict)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        schemaService.dismissEditor()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task {
                            await saveSchema()
                        }
                    }
                    .disabled(name.isEmpty || selectedStrategyURL == nil)
                }
            }
            .onChange(of: selectedStrategyURL) { _, newURL in
                loadStrategyMetadata(from: newURL)
            }
            .onChange(of: keychainFieldNames) { _, newFields in
                if !newFields.isEmpty && isEditing {
                    Task {
                        await authenticateAndLoadKeychain()
                    }
                }
            }
    }

    @ViewBuilder
    private func buildBacktestView() -> some View {
        Form {
            Section("Backtest Engine Configuration") {
                if let backtestSchema = backtestSchema {
                    JSONSchemaForm(schema: backtestSchema, formData: $backtestFormData, showErrorList: false, showSubmitButton: false, controller: backtestController)
                }

                if let error = backtestError {
                    Text(error)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    func buildStrategyView() -> some View {
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
            } else if let schema = strategySchema {
                Section("Parameters") {
                    JSONSchemaForm(
                        schema: schema,
                        uiSchema: keychainUiSchema,
                        formData: $strategyFormData,
                        showSubmitButton: false,
                        controller: strategyController
                    )
                }
            } else if selectedStrategyURL != nil && strategyError == nil {
                Section("Parameters") {
                    Text("Could not load strategy parameters")
                        .foregroundStyle(.secondary)
                }
            }

            if let strategyError {
                Section {
                    Text(strategyError)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func loadStrategyMetadata(from url: URL?) {
        guard let url else {
            strategyMetadata = nil
            strategySchema = nil
            keychainFieldNames = []
            keychainUiSchema = nil
            rawSchemaString = nil
            return
        }

        isLoadingMetadata = true
        strategyError = nil

        Task {
            do {
                let metadata = try await strategyCacheService.getMetadata(for: url)
                strategyMetadata = metadata
                strategySchema = try? JSONSchema(jsonString: metadata.schema)
                rawSchemaString = metadata.schema

                // Parse keychain fields from raw schema
                let fields = KeychainSchemaParser.keychainFieldNames(from: metadata.schema)
                keychainFieldNames = fields
                if !fields.isEmpty {
                    keychainUiSchema = KeychainSchemaParser.buildUiSchema(keychainFields: fields)
                } else {
                    keychainUiSchema = nil
                }

                isLoadingMetadata = false
            } catch {
                self.strategyError = error.localizedDescription
                isLoadingMetadata = false
            }
        }
    }

    private func authenticateAndLoadKeychain() async {
        guard let existingSchema = existingSchema else { return }
        let success = await keychainService.authenticateWithBiometrics()
        if success {
            let values = keychainService.loadKeychainValues(
                identifier: existingSchema.id.uuidString,
                fieldNames: keychainFieldNames
            )
            injectKeychainValues(values)
        }
    }

    private func injectKeychainValues(_ values: [String: String]) {
        guard case .object(var properties) = strategyFormData else { return }
        for (field, value) in values {
            properties[field] = .string(value)
        }
        strategyFormData = .object(properties: properties)
    }

    private func extractKeychainValues() -> [String: String] {
        guard case .object(let properties) = strategyFormData else { return [:] }
        var values: [String: String] = [:]
        for field in keychainFieldNames {
            if case .string(let value) = properties[field], !value.isEmpty {
                values[field] = value
            }
        }
        return values
    }

    private func saveSchema() async {
        guard let strategyURL = selectedStrategyURL else { return }

        // Validate both forms before saving
        do {
            let strategyValid = try await strategyController.submit()
            if !strategyValid {
                alertManager.showAlert(message: "Please fix the errors in the strategy form before saving.")
                return
            }

            let backtestValid = try await backtestController.submit()
            if !backtestValid {
                alertManager.showAlert(message: "Please fix the errors in the backtest form before saving.")
                return
            }
        } catch {
            alertManager.showAlert(message: "Please fix the errors in the form before saving.")
            return
        }

        do {
            var dict: [String: Any] = (strategyFormData.toDictionary() as? [String: Any]) ?? [:]

            // Handle keychain fields: save to keychain and replace with placeholder
            var keychainFieldNamesList: [String] = []
            if !keychainFieldNames.isEmpty {
                let keychainValues = extractKeychainValues()
                if !keychainValues.isEmpty {
                    if !keychainService.isAuthenticated {
                        let success = await keychainService.authenticateWithBiometrics()
                        if !success {
                            alertManager.showAlert(message: "Authentication required to save credentials.")
                            return
                        }
                    }

                    let schemaId: String
                    if isEditing, let existing = existingSchema {
                        schemaId = existing.id.uuidString
                    } else {
                        // Will use the new schema's ID after creation
                        schemaId = UUID().uuidString
                    }

                    keychainService.saveKeychainValues(identifier: schemaId, values: keychainValues)

                    // Replace keychain values with placeholder in saved data
                    for field in keychainFieldNames {
                        dict[field] = "__KEYCHAIN__"
                    }
                    keychainFieldNamesList = Array(keychainFieldNames)
                }
            }

            let parametersData = try JSONSerialization.data(withJSONObject: dict)
            let backtestDict = backtestFormData.toDictionary() ?? [:]
            let backtestData = try JSONSerialization.data(withJSONObject: backtestDict)
            let strategyPath = strategyURL.lastPathComponent

            if isEditing, let existing = existingSchema {
                var updated = existing
                updated.name = name
                updated.strategyPath = strategyPath
                updated.parameters = parametersData
                updated.backtestEngineConfig = backtestData
                updated.keychainFieldNames = keychainFieldNamesList.isEmpty ? existing.keychainFieldNames : keychainFieldNamesList
                updated.updatedAt = Date()
                document.updateSchema(updated)
            } else {
                let schema = Schema(
                    name: name,
                    parameters: parametersData,
                    backtestEngineConfig: backtestData,
                    strategyPath: strategyPath,
                    keychainFieldNames: keychainFieldNamesList
                )
                document.addSchema(schema)
            }
            schemaService.dismissEditor()
            dismiss()
        } catch {
            alertManager.showAlert(message: error.localizedDescription)
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
    .environment(AlertManager())
    .environment(StrategyCacheService())
    .environment(KeychainService())
}

#Preview("Edit") {
    SchemaEditorView(
        document: .constant(ArgoTradingDocument()),
        isEditing: true,
        existingSchema: Schema(name: "Test Schema", strategyPath: "test.wasm")
    )
    .environment(SchemaService())
    .environment(StrategyService())
    .environment(AlertManager())
    .environment(StrategyCacheService())
    .environment(KeychainService())
}
