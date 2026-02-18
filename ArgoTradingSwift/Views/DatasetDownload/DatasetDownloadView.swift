//
//  DatasetDownloadView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import ArgoTrading
import JSONSchema
import JSONSchemaForm
import SwiftUI

struct DatasetDownloadView: View {
    @AppStorage("data-provider") private var dataProvider: String = ""

    @Binding var document: ArgoTradingDocument

    @Environment(DatasetDownloadService.self) var datasetDownloadService
    @Environment(AlertManager.self) var alertManager
    @Environment(ToolbarStatusService.self) var toolbarStatusService
    @Environment(KeychainService.self) var keychainService
    @Environment(\.dismiss) var dismiss

    private let supportedProviders: [String]
    @State private var showFilePicker: Bool = false
    @State private var formData: FormData = .object(properties: [:])
    @State private var controller = JSONSchemaFormController()

    @State private var keychainFieldNames: Set<String> = []
    @State private var uiSchema: [String: Any]?
    @State private var keychainAuthenticated: Bool = false
    @State private var keychainAuthError: String?
    @State private var providerSchema: JSONSchema?
    @State private var isLoadingKeychain: Bool = false

    init(document: Binding<ArgoTradingDocument>) {
        _document = document
        if let providers = SwiftargoGetSupportedDownloadClients(), let stringProviders = providers as? SwiftargoStringCollection {
            supportedProviders = stringProviders.stringArray
        } else {
            supportedProviders = []
        }
    }

    var body: some View {
        NavigationStack {
            if datasetDownloadService.isDownloading {
                ProgressView(value: datasetDownloadService.currentProgress,
                             total: datasetDownloadService.totalProgress)
                {
                    Text("Downloading")
                    Text("Progress: \(datasetDownloadService.progressPercentage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .navigationTitle("Downloading Dataset")
            } else {
                Form {
                    Section("Data Provider") {
                        Picker("Provider", selection: $dataProvider) {
                            if supportedProviders.isEmpty {
                                Text("Loading...").tag("")
                            }

                            ForEach(supportedProviders, id: \.self) { provider in
                                Text(provider).tag(provider)
                            }
                        }
                    }

                    if !dataProvider.isEmpty {
                        if isLoadingKeychain {
                            Section("Provider Configuration") {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Loading saved credentials...")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if !keychainFieldNames.isEmpty && !keychainAuthenticated {
                            Section {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.yellow)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Authentication required to load saved credentials")
                                            .font(.callout)
                                        if let error = keychainAuthError {
                                            Text(error)
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    Spacer()
                                    Button("Authenticate") {
                                        Task {
                                            await authenticateAndLoadKeychain()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else {
                            Section("Provider Configuration") {
                                if let jsonSchema = providerSchema {
                                    JSONSchemaForm(schema: jsonSchema, uiSchema: uiSchema, formData: $formData, showSubmitButton: false, controller: controller)
                                } else {
                                    Text("Failed to load provider configuration schema.")
                                }
                            }
                        }
                    }
                }
                .disabled(datasetDownloadService.isDownloading)
                .padding()
                .formStyle(.grouped)
            }
        }
        .alertManager(alertManager)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if datasetDownloadService.isDownloading {
                    Button("Stop") {
                        datasetDownloadService.cancel()
                    }
                } else {
                    Button("Download") {
                        Task {
                            await downloadDataset()
                        }
                    }
                }
            }

            if !datasetDownloadService.isDownloading {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: dataProvider) { _, newProvider in
            updateKeychainFields(for: newProvider)
        }
        .onAppear {
            if !dataProvider.isEmpty {
                updateKeychainFields(for: dataProvider)
            }
        }
    }

    private func updateKeychainFields(for provider: String) {
        guard !provider.isEmpty else {
            keychainFieldNames = []
            uiSchema = nil
            providerSchema = nil
            return
        }

        // Cache the schema to prevent re-parsing on every render
        let schemaString = SwiftargoGetDownloadClientSchema(provider)
        providerSchema = try? JSONSchema(jsonString: schemaString)

        // Extract property order from the raw schema string
        let propertyOrder = KeychainSchemaParser.propertyOrder(from: schemaString)

        if let fields = SwiftargoGetDownloadClientKeychainFields(provider),
           let stringFields = fields as? SwiftargoStringCollection
        {
            keychainFieldNames = Set(stringFields.stringArray)
        } else {
            keychainFieldNames = []
        }

        // Always build uiSchema to preserve field order
        uiSchema = KeychainSchemaParser.buildUiSchema(
            keychainFields: keychainFieldNames,
            propertyOrder: propertyOrder
        )

        if !keychainFieldNames.isEmpty {
            Task {
                await authenticateAndLoadKeychain()
            }
        }
    }

    private func authenticateAndLoadKeychain() async {
        isLoadingKeychain = true
        let success = await keychainService.authenticateWithBiometrics()
        keychainAuthenticated = success
        if success {
            keychainAuthError = nil
            let values = keychainService.loadKeychainValues(
                identifier: dataProvider,
                fieldNames: keychainFieldNames
            )
            injectKeychainValues(values)
        } else {
            keychainAuthError = keychainService.authError
        }
        isLoadingKeychain = false
    }

    private func injectKeychainValues(_ values: [String: String]) {
        guard case .object(var properties) = formData else { return }
        for (field, value) in values {
            properties[field] = .string(value)
        }
        formData = .object(properties: properties)
    }

    private func extractKeychainValues() -> [String: String] {
        guard case .object(let properties) = formData else { return [:] }
        var values: [String: String] = [:]
        for field in keychainFieldNames {
            if case .string(let value) = properties[field], !value.isEmpty {
                values[field] = value
            }
        }
        return values
    }
}

extension DatasetDownloadView {
    func downloadDataset() async {
        do {
            let success = try await controller.submit()
            if !success {
                return
            }
        } catch {
            alertManager.showAlert(message: "Please fix the errors in the form before downloading.")
            return
        }

        // Save keychain field values before downloading
        if !keychainFieldNames.isEmpty {
            if !keychainAuthenticated {
                let success = await keychainService.authenticateWithBiometrics()
                if !success {
                    alertManager.showAlert(message: "Authentication required to save credentials.")
                    return
                }
                keychainAuthenticated = true
            }
            let values = extractKeychainValues()
            keychainService.saveKeychainValues(identifier: dataProvider, values: values)
        }

        let marketDownloader = SwiftargoMarketDownloader(datasetDownloadService)
        datasetDownloadService.marketDownloader = marketDownloader

        datasetDownloadService.toolbarStatusService = toolbarStatusService
        // Move download process to background thread
        datasetDownloadService.downloadTask = Task.detached {
            do {
                await MainActor.run {
                    self.datasetDownloadService.isDownloading = true
                }

                let jsonEncoder = JSONEncoder()
                let configData = try await jsonEncoder.encode(self.formData)
                try await marketDownloader!.download(withConfig: dataProvider, configJSON: String(data: configData, encoding: .utf8) ?? "{}", dataFolder: document.dataFolder.path(percentEncoded: false))

                // Check cancellation before dismissing
                if !Task.isCancelled {
                    await self.toolbarStatusService.setStatus(.finished(
                        message: "Downloaded",
                        at: Date()
                    ))
                    await dismiss()
                }
            } catch is CancellationError {
                // User cancelled - no alert needed (cancel() already sets idle status)
                print("Download cancelled")
            } catch {
                // skip alert for context canceled errors
                if error.isContextCancelled {
                    await self.toolbarStatusService.setStatus(.downloadCancelled(label: "Dataset Download"))
                    return
                }
                await MainActor.run {
                    self.alertManager.showAlert(message: error.localizedDescription)
                }
                await self.toolbarStatusService.setStatus(.error(
                    label: "Dataset Download",
                    errors: [error.localizedDescription],
                    at: Date()
                ))
            }
            await MainActor.run {
                self.datasetDownloadService.isDownloading = false
                self.datasetDownloadService.downloadTask = nil
            }
        }
    }
}
