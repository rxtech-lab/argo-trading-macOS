//
//  DatasetDownloadView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import ArgoTrading
import SwiftUI

struct DatasetDownloadView: View {
    @Binding var document: ArgoTradingDocument

    @Environment(DatasetDownloadService.self) var datasetDownloadService
    @Environment(AlertManager.self) var alertManager
    @Environment(ToolbarStatusService.self) var toolbarStatusService
    @Environment(\.dismiss) var dismiss

    @AppStorage("ticker") private var ticker: String = ""
    @AppStorage("start-time") private var startDate: Date = .init()
    @AppStorage("end-time") private var endDate: Date = .init()
    @AppStorage("span") private var timespan: Timespan = .oneMinute
    @AppStorage("data-provider") private var dataProvider: DataProvider = .Binance
    @AppStorage("polygon-api-key") private var polygonApiKey: String = ""

    @AppStorage("writer") private var writer: DataWriter = .duckdb

    @State private var showFilePicker: Bool = false

    var body: some View {
        NavigationStack {
            if datasetDownloadService.isDownloading {
                ProgressView(value: datasetDownloadService.currentProgress,
                             total: datasetDownloadService.totalProgress)
                {
                    Text("Downloading \(dataProvider.rawValue)-\(ticker)-\(formattedStartDate)-\(formattedEndDate)")
                    Text("Progress: \(datasetDownloadService.progressPercentage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .navigationTitle("Downloading Dataset")
            } else {
                Form {
                    Section(header: Text("Data Provider")) {
                        Picker("Data Provider", selection: $dataProvider) {
                            ForEach(DataProvider.allCases) { provider in
                                Text(provider.rawValue.capitalized).tag(provider)
                            }
                        }
                        dataProvider.providerField
                    }

                    Section(header: Text("Writer config")) {
                        Picker("Writer", selection: $writer) {
                            ForEach(DataWriter.allCases) { writer in
                                Text(writer.rawValue).tag(writer)
                            }
                        }
                        writer.writerField
                    }

                    Section(header: Text("Dataset Config")) {
                        TextField("Ticker", text: $ticker)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])

                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date])

                        Picker("Timespan", selection: $timespan) {
                            ForEach(Timespan.allCases, id: \.self) { timespan in
                                Text(timespan.rawValue).tag(timespan)
                            }
                        }
                    }
                }
                .frame(minHeight: 400)
                .padding()
                .navigationTitle("Download Dataset")
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
                        downloadDataset()
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
    private var formattedStartDate: String {
        startDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    private var formattedEndDate: String {
        endDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    func downloadDataset() {
        guard !ticker.isEmpty else {
            alertManager.showAlert(message: "Ticker cannot be empty")
            return
        }

        let marketDownloader = SwiftargoNewMarketDownloader(datasetDownloadService, dataProvider.rawValue, writer.rawValue, document.dataFolder.path(percentEncoded: false), polygonApiKey)
        datasetDownloadService.marketDownloader = marketDownloader

        datasetDownloadService.toolbarStatusService = toolbarStatusService
        datasetDownloadService.currentTicker = ticker

        // Move download process to background thread
        datasetDownloadService.downloadTask = Task.detached {
            do {
                await MainActor.run {
                    self.datasetDownloadService.isDownloading = true
                }
                try await marketDownloader!.download(self.ticker, from: self.startDate.ISO8601Format(), to: self.endDate.ISO8601Format(), interval: self.timespan.rawValue)

                // Check cancellation before dismissing
                if !Task.isCancelled {
                    await self.toolbarStatusService.setStatus(.finished(
                        message: "Downloaded \(self.ticker)",
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
