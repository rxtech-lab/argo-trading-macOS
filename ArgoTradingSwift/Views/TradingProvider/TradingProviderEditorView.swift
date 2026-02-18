//
//  TradingProviderEditorView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import ArgoTrading
import JSONSchema
import JSONSchemaForm
import SwiftUI

struct TradingProviderEditorView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(TradingProviderService.self) var tradingProviderService
    @Environment(AlertManager.self) var alertManager
    @Environment(KeychainService.self) var keychainService
    @Environment(\.dismiss) var dismiss

    let isEditing: Bool
    let existingProvider: TradingProvider?

    // General
    @State private var name: String = ""

    // Trading System tab
    @State private var selectedTradingSystemProvider: String = ""
    @State private var tradingSystemSchema: JSONSchema?
    @State private var tradingSystemFormData: FormData = .object(properties: [:])
    @State private var tradingSystemController = JSONSchemaFormController()
    @State private var keychainFieldNames: Set<String> = []
    @State private var keychainUiSchema: [String: Any]?

    // Live Trading Engine tab
    @State private var selectedMarketDataProvider: String = ""
    @State private var engineSchema: JSONSchema?
    @State private var engineFormData: FormData = .object(properties: [:])
    @State private var engineController = JSONSchemaFormController()

    // Providers lists
    private let supportedTradingProviders: [String]
    private let supportedMarketDataProviders: [String]

    init(
        document: Binding<ArgoTradingDocument>,
        isEditing: Bool,
        existingProvider: TradingProvider?
    ) {
        _document = document
        self.isEditing = isEditing
        self.existingProvider = existingProvider

        if let providers = SwiftargoGetSupportedTradingProviders(),
           let stringProviders = providers as? SwiftargoStringCollection
        {
            supportedTradingProviders = stringProviders.stringArray
        } else {
            supportedTradingProviders = []
        }

        if let providers = SwiftargoGetSupportedMarketDataProviders(),
           let stringProviders = providers as? SwiftargoStringCollection
        {
            supportedMarketDataProviders = stringProviders.stringArray
        } else {
            supportedMarketDataProviders = []
        }
    }

    var body: some View {
        TabView {
            Tab("Trading System", systemImage: "network") {
                buildTradingSystemView()
            }
            Tab("Live Trading Engine", systemImage: "gearshape.2.fill") {
                buildEngineView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .alertManager(alertManager)
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            loadEngineSchema()
            if isEditing, let provider = existingProvider {
                name = provider.name
                selectedTradingSystemProvider = provider.tradingSystemProvider
                selectedMarketDataProvider = provider.marketDataProvider
                if let dict = try? JSONSerialization.jsonObject(with: provider.tradingSystemConfig) {
                    tradingSystemFormData = formDataFromAny(dict)
                }
                if let dict = try? JSONSerialization.jsonObject(with: provider.liveTradingEngineConfig) {
                    engineFormData = formDataFromAny(dict)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    tradingProviderService.dismissEditor()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Create") {
                    Task {
                        await saveProvider()
                    }
                }
                .disabled(name.isEmpty || selectedTradingSystemProvider.isEmpty)
            }
        }
        .onChange(of: selectedTradingSystemProvider) { _, newProvider in
            updateTradingSystemSchema(for: newProvider)
        }
        .onChange(of: keychainFieldNames) { _, newFields in
            if !newFields.isEmpty && isEditing {
                Task {
                    await authenticateAndLoadKeychain()
                }
            }
        }
    }

    // MARK: - Trading System Tab

    @ViewBuilder
    private func buildTradingSystemView() -> some View {
        Form {
            Section("General") {
                TextField("Provider Name", text: $name)

                Picker("Trading System", selection: $selectedTradingSystemProvider) {
                    Text("Select a provider").tag("")
                    ForEach(supportedTradingProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
            }

            if let schema = tradingSystemSchema {
                Section("Configuration") {
                    JSONSchemaForm(
                        schema: schema,
                        uiSchema: keychainUiSchema,
                        formData: $tradingSystemFormData,
                        showSubmitButton: false,
                        controller: tradingSystemController
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Live Trading Engine Tab

    @ViewBuilder
    private func buildEngineView() -> some View {
        Form {
            Section("Market Data") {
                Picker("Market Data Provider", selection: $selectedMarketDataProvider) {
                    Text("Select a provider").tag("")
                    ForEach(supportedMarketDataProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
            }

            if let schema = engineSchema {
                Section("Engine Configuration") {
                    JSONSchemaForm(
                        schema: schema,
                        formData: $engineFormData,
                        showErrorList: false,
                        showSubmitButton: false,
                        controller: engineController
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Schema Loading

    private func loadEngineSchema() {
        let schemaString = SwiftargoGetLiveTradingEngineConfigSchema()
        engineSchema = try? JSONSchema(jsonString: schemaString)
    }

    private func updateTradingSystemSchema(for provider: String) {
        guard !provider.isEmpty else {
            tradingSystemSchema = nil
            keychainFieldNames = []
            keychainUiSchema = nil
            return
        }

        let schemaString = SwiftargoGetTradingProviderSchema(provider)
        tradingSystemSchema = try? JSONSchema(jsonString: schemaString)

        let propertyOrder = KeychainSchemaParser.propertyOrder(from: schemaString)

        if let fields = SwiftargoGetTradingProviderKeychainFields(provider),
           let stringFields = fields as? SwiftargoStringCollection
        {
            keychainFieldNames = Set(stringFields.stringArray)
        } else {
            keychainFieldNames = []
        }

        keychainUiSchema = KeychainSchemaParser.buildUiSchema(
            keychainFields: keychainFieldNames,
            propertyOrder: propertyOrder
        )
    }

    // MARK: - Keychain

    private func authenticateAndLoadKeychain() async {
        guard let existingProvider = existingProvider else { return }
        let success = await keychainService.authenticateWithBiometrics()
        if success {
            let values = keychainService.loadKeychainValues(
                identifier: existingProvider.id.uuidString,
                fieldNames: keychainFieldNames
            )
            injectKeychainValues(values)
        }
    }

    private func injectKeychainValues(_ values: [String: String]) {
        guard case .object(var properties) = tradingSystemFormData else { return }
        for (field, value) in values {
            properties[field] = .string(value)
        }
        tradingSystemFormData = .object(properties: properties)
    }

    private func extractKeychainValues() -> [String: String] {
        guard case .object(let properties) = tradingSystemFormData else { return [:] }
        var values: [String: String] = [:]
        for field in keychainFieldNames {
            if case .string(let value) = properties[field], !value.isEmpty {
                values[field] = value
            }
        }
        return values
    }

    // MARK: - Save

    private func saveProvider() async {
        // Validate forms
        do {
            let tradingValid = try await tradingSystemController.submit()
            if !tradingValid {
                alertManager.showAlert(message: "Please fix the errors in the trading system form before saving.")
                return
            }
            let engineValid = try await engineController.submit()
            if !engineValid {
                alertManager.showAlert(message: "Please fix the errors in the engine form before saving.")
                return
            }
        } catch {
            alertManager.showAlert(message: "Please fix the errors in the form before saving.")
            return
        }

        do {
            var dict: [String: Any] = (tradingSystemFormData.toDictionary() as? [String: Any]) ?? [:]

            // Handle keychain fields
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

                    let providerId: String
                    if isEditing, let existing = existingProvider {
                        providerId = existing.id.uuidString
                    } else {
                        providerId = UUID().uuidString
                    }

                    keychainService.saveKeychainValues(identifier: providerId, values: keychainValues)

                    // Replace keychain values with placeholder
                    for field in keychainFieldNames {
                        dict[field] = "__KEYCHAIN__"
                    }
                    keychainFieldNamesList = Array(keychainFieldNames)
                }
            }

            let tradingConfigData = try JSONSerialization.data(withJSONObject: dict)
            let engineDict = engineFormData.toDictionary() ?? [:]
            let engineConfigData = try JSONSerialization.data(withJSONObject: engineDict)

            if isEditing, let existing = existingProvider {
                var updated = existing
                updated.name = name
                updated.tradingSystemProvider = selectedTradingSystemProvider
                updated.marketDataProvider = selectedMarketDataProvider
                updated.tradingSystemConfig = tradingConfigData
                updated.liveTradingEngineConfig = engineConfigData
                updated.keychainFieldNames = keychainFieldNamesList.isEmpty ? existing.keychainFieldNames : keychainFieldNamesList
                updated.updatedAt = Date()
                document.updateTradingProvider(updated)
            } else {
                let provider = TradingProvider(
                    name: name,
                    marketDataProvider: selectedMarketDataProvider,
                    tradingSystemProvider: selectedTradingSystemProvider,
                    tradingSystemConfig: tradingConfigData,
                    liveTradingEngineConfig: engineConfigData,
                    keychainFieldNames: keychainFieldNamesList
                )
                document.addTradingProvider(provider)
            }
            tradingProviderService.dismissEditor()
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
