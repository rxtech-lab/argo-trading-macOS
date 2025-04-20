//
//  DatasetDownloadView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import ArgoTrading
import SwiftUI

struct DatasetDownloadView: View {
    @Environment(DatasetDownloadService.self) var datasetDownloadService
    @Environment(AlertManager.self) var alertManager
    @Environment(\.dismiss) var dismiss

    @AppStorage("ticker") private var ticker: String = ""
    @AppStorage("start-time") private var startDate: Date = .init()
    @AppStorage("end-time") private var endDate: Date = .init()
    @AppStorage("span") private var timespan: Timespan = .oneMinute
    @AppStorage("data-provider") private var dataProvider: DataProvider = .Binance
    @AppStorage("polygon-api-key") private var polygonApiKey: String = ""

    @AppStorage("writer") private var writer: DataWriter = .duckdb
    @AppStorage("duckdb-data-folder") private var dataFolder: String = ""

    @State private var showFilePicker: Bool = false

    var body: some View {
        NavigationStack {
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
            .disabled(datasetDownloadService.isDownloading)
            .frame(minHeight: 400)
            .padding()
            .navigationTitle("Download Dataset")
            .formStyle(.grouped)
            .alertManager(alertManager)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(datasetDownloadService.isDownloading ? "Downloading: \(datasetDownloadService.progressPercentage)" : "Download") {
                    downloadDataset()
                }
                .disabled(datasetDownloadService.isDownloading)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

extension DatasetDownloadView {
    func downloadDataset() {
        guard !ticker.isEmpty else {
            alertManager.showAlert(message: "Ticker cannot be empty")
            return
        }

        let marketDownloader = SwiftargoNewMarketDownloader(datasetDownloadService, dataProvider.rawValue, writer.rawValue, dataFolder, polygonApiKey)

        // Move download process to background thread
        Task.detached {
            do {
                await MainActor.run {
                    self.datasetDownloadService.isDownloading = true
                }
                try await marketDownloader!.download(self.ticker, from: self.startDate.ISO8601Format(), to: self.endDate.ISO8601Format(), interval: self.timespan.rawValue)
            } catch {
                await MainActor.run {
                    self.alertManager.showAlert(message: error.localizedDescription)
                }
            }
            await MainActor.run {
                self.datasetDownloadService.isDownloading = false
                dismiss()
            }
        }
    }
}
