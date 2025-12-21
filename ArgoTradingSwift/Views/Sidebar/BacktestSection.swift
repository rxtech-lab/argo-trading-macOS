//
//  BacktestSection.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

struct BacktestSection: View {
    let dataFolder: URL

    @State private var expandedData = true
    @State private var error: String?
    @State private var resultFolderWatcher: FolderMonitor? = nil
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?

    @State var files: [URL] = []

    var body: some View {
        Section("Backtest options") {
            DisclosureGroup("Data", isExpanded: $expandedData) {
                ForEach(files, id: \.self) { file in
                    NavigationLink(value: NavigationPath.backtest(backtest: .data(url: file))) {
                        ParquetFileRow(fileName: file.lastPathComponent)
                            .contextMenu {
                                Button(role: .destructive) {
                                    fileToDelete = file
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .onAppear {
            listParquetFile()
            Task {
                await watchFolder(folder: dataFolder)
            }
        }
        .onChange(of: dataFolder) { _, newValue in
            listParquetFile()
            Task {
                await watchFolder(folder: newValue)
            }
        }
        .alert("Delete File", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    deleteFile(file)
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete \"\(file.lastPathComponent)\"? This action cannot be undone.")
            }
        }
    }
}

extension BacktestSection {
    func deleteFile(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            self.error = error.localizedDescription
            print("Error deleting file: \(error.localizedDescription)")
        }
    }

    func listParquetFile() {
        files.removeAll()
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: dataFolder, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "parquet" {
                    files.append(fileURL)
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
