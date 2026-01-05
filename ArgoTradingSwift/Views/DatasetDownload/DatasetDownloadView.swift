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
    @AppStorage("config") private var configData: String = "{}"
    @AppStorage("data-provider") private var dataProvider: String = ""

    @Binding var document: ArgoTradingDocument

    @Environment(DatasetDownloadService.self) var datasetDownloadService
    @Environment(AlertManager.self) var alertManager
    @Environment(ToolbarStatusService.self) var toolbarStatusService
    @Environment(\.dismiss) var dismiss

    private let supportedProviders: [String]
    @State private var showFilePicker: Bool = false
    @State private var formData: FormData = .object(properties: [:])
    @State private var controller = JSONSchemaFormController()

    private var providerSchema: String {
        let schema = SwiftargoGetDownloadClientSchema(dataProvider)
        return schema
    }

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
                        Section("Provider Configuration") {
                            if let jsonSchema = try? JSONSchema(jsonString: providerSchema) {
                                JSONSchemaForm(schema: jsonSchema, formData: $formData, showSubmitButton: false, controller: controller)
                            } else {
                                Text("Failed to load provider configuration schema.")
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
