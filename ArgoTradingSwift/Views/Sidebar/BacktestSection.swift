//
//  BacktestSection.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

struct BacktestSection: View {
    @Environment(DatasetDownloadService.self) var downloadService

    @State private var expandedData = true
    @AppStorage("duckdb-data-folder") private var duckdbDataFolder: String = ""
    @State private var error: String?
    @State private var resultFolderWatcher: FolderMonitor? = nil

    @State var files: [URL] = []

    var body: some View {
        Section("Backtest options") {
            DisclosureGroup("Data", isExpanded: $expandedData) {
                ForEach(files, id: \.self) { file in
                    NavigationLink(value: NavigationPath.backtest(backtest: .data(url: file))) {
                        Text(file.lastPathComponent.replacingOccurrences(of: ".parquet", with: ""))
                            .truncationMode(.middle)
                            .contextMenu {
                                Button {} label: {
                                    Text("Delete")
                                }
                            }
                    }
                }
            }
        }
        .onAppear {
            if !duckdbDataFolder.isEmpty {
                listParquetFile()
                Task {
                    await watchFolder(folder: URL(fileURLWithPath: duckdbDataFolder))
                }
            }
        }
        .onChange(of: duckdbDataFolder) { newValue, _ in
            if !newValue.isEmpty {
                Task {
                    await watchFolder(folder: URL(fileURLWithPath: newValue))
                }
            }
        }
    }
}

extension BacktestSection {
    func listParquetFile() {
        files.removeAll()
        let fileManager = FileManager.default
        let duckDBDataFolderURL = URL(fileURLWithPath: duckdbDataFolder)
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: duckDBDataFolderURL, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "parquet" {
                    if let url = URL(string: fileURL.absoluteString) {
                        files.append(url)
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Error listing files: \(error.localizedDescription)")
        }
    }

    func watchFolder(folder: URL) async {
        resultFolderWatcher?.stopMonitoring()
        resultFolderWatcher = FolderMonitor(url: folder)
        for await _ in resultFolderWatcher!.startMonitoring() {
            listParquetFile()
        }
    }
}
