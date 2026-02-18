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

enum TradingProviderSection: String, CaseIterable, Identifiable {
    case liveDataProvider = "Live Trading Provider"
    case liveTradingProvider = "Live Data Provider"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .liveDataProvider: return "network"
        case .liveTradingProvider: return "gearshape.2.fill"
        }
    }
}

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

    // Navigation
    @State private var selectedSection: TradingProviderSection? = .liveDataProvider

    // Trading System tab
    @State private var selectedTradingSystemProvider: String = ""
    @State private var tradingSystemSchema: JSONSchema?
    @State private var tradingSystemFormData: FormData = .object(properties: [:])
    @State private var tradingSystemController = JSONSchemaFormController()
    @State private var keychainFieldNames: Set<String> = []
    @State private var keychainUiSchema: [String: Any]?
    @State private var isLoadingTradingKeychain = false

    // Live Trading Provider tab
    @State private var selectedMarketDataProvider: String = ""
    @State private var marketDataProviderSchema: JSONSchema?
    @State private var marketDataProviderFormData: FormData = .object(properties: [:])
    @State private var marketDataProviderController = JSONSchemaFormController()
    @State private var marketDataKeychainFieldNames: Set<String> = []
    @State private var marketDataKeychainUiSchema: [String: Any]?
    @State private var isLoadingMarketDataKeychain = false

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
        NavigationSplitView {
            List(TradingProviderSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            if let section = selectedSection {
                switch section {
                case .liveDataProvider:
                    buildTradingSystemView()
                case .liveTradingProvider:
                    buildMarketDataProviderView()
                }
            } else {
                ContentUnavailableView("Select a Section", systemImage: "sidebar.left")
            }
        }
        .frame(minWidth: 600, minHeight: 700)
        .alertManager(alertManager)
        .onAppear {
            if isEditing, let provider = existingProvider {
                name = provider.name
                selectedTradingSystemProvider = provider.tradingSystemProvider
                selectedMarketDataProvider = provider.marketDataProvider
                if let dict = try? JSONSerialization.jsonObject(with: provider.tradingSystemConfig) {
                    tradingSystemFormData = formDataFromAny(dict)
                }
                if let dict = try? JSONSerialization.jsonObject(with: provider.liveTradingEngineConfig) {
                    marketDataProviderFormData = formDataFromAny(dict)
                }
                // Load schemas directly so keychain field names are populated synchronously
                updateTradingSystemSchema(for: provider.tradingSystemProvider)
                updateMarketDataProviderSchema(for: provider.marketDataProvider)

                // Set loading flags synchronously so the form never flashes __KEYCHAIN__
                if !keychainFieldNames.isEmpty { isLoadingTradingKeychain = true }
                if !marketDataKeychainFieldNames.isEmpty { isLoadingMarketDataKeychain = true }

                // Authenticate once and load all keychain values
                Task {
                    await loadAllKeychainValues(for: provider)
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
        .onChange(of: selectedMarketDataProvider) { _, newProvider in
            updateMarketDataProviderSchema(for: newProvider)
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
                if isLoadingTradingKeychain {
                    Section("Configuration") {
                        ProgressView("Loading credentials...")
                    }
                } else {
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
        }
        .formStyle(.grouped)
    }

    // MARK: - Live Trading Provider Tab

    @ViewBuilder
    private func buildMarketDataProviderView() -> some View {
        Form {
            Section("Market Data") {
                Picker("Market Data Provider", selection: $selectedMarketDataProvider) {
                    Text("Select a provider").tag("")
                    ForEach(supportedMarketDataProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
            }

            if let schema = marketDataProviderSchema {
                if isLoadingMarketDataKeychain {
                    Section("Provider Configuration") {
                        ProgressView("Loading credentials...")
                    }
                } else {
                    Section("Provider Configuration") {
                        JSONSchemaForm(
                            schema: schema,
                            uiSchema: marketDataKeychainUiSchema,
                            formData: $marketDataProviderFormData,
                            showErrorList: false,
                            showSubmitButton: false,
                            controller: marketDataProviderController
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Schema Loading

    private func updateMarketDataProviderSchema(for provider: String) {
        guard !provider.isEmpty else {
            marketDataProviderSchema = nil
            marketDataKeychainFieldNames = []
            marketDataKeychainUiSchema = nil
            return
        }

        let schemaString = SwiftargoGetMarketDataProviderSchema(provider)
        marketDataProviderSchema = try? JSONSchema(jsonString: schemaString)

        let propertyOrder = KeychainSchemaParser.propertyOrder(from: schemaString)

        if let fields = SwiftargoGetMarketDataProviderKeychainFields(provider),
           let stringFields = fields as? SwiftargoStringCollection
        {
            marketDataKeychainFieldNames = Set(stringFields.stringArray)
        } else {
            marketDataKeychainFieldNames = []
        }

        marketDataKeychainUiSchema = KeychainSchemaParser.buildUiSchema(
            keychainFields: marketDataKeychainFieldNames,
            propertyOrder: propertyOrder
        )
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

    private func loadAllKeychainValues(for provider: TradingProvider) async {
        let hasTradingKeychain = !keychainFieldNames.isEmpty
        let hasMarketDataKeychain = !marketDataKeychainFieldNames.isEmpty

        guard hasTradingKeychain || hasMarketDataKeychain else { return }

        defer {
            isLoadingTradingKeychain = false
            isLoadingMarketDataKeychain = false
        }

        // Authenticate once for both
        let success = await keychainService.authenticateWithBiometrics()
        logger.info("loadAllKeychainValues: auth result=\(success)")
        guard success else { return }

        if hasTradingKeychain {
            let values = keychainService.loadKeychainValues(
                identifier: provider.id.uuidString,
                fieldNames: keychainFieldNames
            )
            logger.info("loadAllKeychainValues: trading loaded \(values.count) values")
            injectKeychainValues(values)
        }

        if hasMarketDataKeychain {
            let values = keychainService.loadKeychainValues(
                identifier: "\(provider.id.uuidString)-marketdata",
                fieldNames: marketDataKeychainFieldNames
            )
            logger.info("loadAllKeychainValues: marketData loaded \(values.count) values")
            injectMarketDataKeychainValues(values)
        }
    }

    private func injectKeychainValues(_ values: [String: String]) {
        logger.info("injectKeychainValues: injecting \(values.count) fields")
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
            if case .string(let value) = properties[field], 
               !value.isEmpty,
               value != "__KEYCHAIN__" {
                values[field] = value
            }
        }
        return values
    }

    // MARK: - Market Data Provider Keychain

    private func injectMarketDataKeychainValues(_ values: [String: String]) {
        logger.info("injectMarketDataKeychainValues: injecting \(values.count) fields")
        guard case .object(var properties) = marketDataProviderFormData else { return }
        for (field, value) in values {
            properties[field] = .string(value)
        }
        marketDataProviderFormData = .object(properties: properties)
    }

    private func extractMarketDataKeychainValues() -> [String: String] {
        guard case .object(let properties) = marketDataProviderFormData else { return [:] }
        var values: [String: String] = [:]
        for field in marketDataKeychainFieldNames {
            if case .string(let value) = properties[field], 
               !value.isEmpty,
               value != "__KEYCHAIN__" {
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
            if marketDataProviderSchema != nil {
                let providerValid = try await marketDataProviderController.submit()
                if !providerValid {
                    alertManager.showAlert(message: "Please fix the errors in the market data provider form before saving.")
                    return
                }
            }
        } catch {
            alertManager.showAlert(message: "Please fix the errors in the form before saving.")
            return
        }

        do {
            var dict: [String: Any] = (tradingSystemFormData.toDictionary() as? [String: Any]) ?? [:]

            let providerId: String
            if isEditing, let existing = existingProvider {
                providerId = existing.id.uuidString
            } else {
                providerId = UUID().uuidString
            }

            // Handle trading system keychain fields
            var keychainFieldNamesList: [String] = []
            if !keychainFieldNames.isEmpty {
                let keychainValues = extractKeychainValues()
                logger.info("Trading system keychain fields: \(keychainFieldNames)")
                logger.info("Extracted keychain values count: \(keychainValues.count)")
                logger.info("Extracted keychain values: \(keychainValues)")
                
                if !keychainValues.isEmpty {
                    if !keychainService.isAuthenticated {
                        let success = await keychainService.authenticateWithBiometrics()
                        if !success {
                            alertManager.showAlert(message: "Authentication required to save credentials.")
                            return
                        }
                    }

                    keychainService.saveKeychainValues(identifier: providerId, values: keychainValues)
                    logger.info("Saved keychain values for identifier: \(providerId)")

                    // Replace keychain values with placeholder
                    for field in keychainFieldNames {
                        dict[field] = "__KEYCHAIN__"
                    }
                    keychainFieldNamesList = Array(keychainFieldNames)
                } else {
                    logger.warning("No keychain values extracted - credentials may not be saved!")
                }
            }

            // Handle market data provider keychain fields
            var marketDataDict: [String: Any] = (marketDataProviderFormData.toDictionary() as? [String: Any]) ?? [:]
            if !marketDataKeychainFieldNames.isEmpty {
                let keychainValues = extractMarketDataKeychainValues()
                if !keychainValues.isEmpty {
                    if !keychainService.isAuthenticated {
                        let success = await keychainService.authenticateWithBiometrics()
                        if !success {
                            alertManager.showAlert(message: "Authentication required to save credentials.")
                            return
                        }
                    }

                    keychainService.saveKeychainValues(identifier: "\(providerId)-marketdata", values: keychainValues)

                    for field in marketDataKeychainFieldNames {
                        marketDataDict[field] = "__KEYCHAIN__"
                    }
                }
            }

            let tradingConfigData = try JSONSerialization.data(withJSONObject: dict)
            let marketDataConfigData = try JSONSerialization.data(withJSONObject: marketDataDict)

            if isEditing, let existing = existingProvider {
                var updated = existing
                updated.name = name
                updated.tradingSystemProvider = selectedTradingSystemProvider
                updated.marketDataProvider = selectedMarketDataProvider
                updated.tradingSystemConfig = tradingConfigData
                updated.liveTradingEngineConfig = marketDataConfigData
                updated.keychainFieldNames = keychainFieldNamesList.isEmpty ? existing.keychainFieldNames : keychainFieldNamesList
                updated.updatedAt = Date()
                document.updateTradingProvider(updated)
            } else {
                let provider = TradingProvider(
                    id: UUID(uuidString: providerId)!,
                    name: name,
                    marketDataProvider: selectedMarketDataProvider,
                    tradingSystemProvider: selectedTradingSystemProvider,
                    tradingSystemConfig: tradingConfigData,
                    liveTradingEngineConfig: marketDataConfigData,
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

}
