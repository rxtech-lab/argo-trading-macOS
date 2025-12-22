//
//  StrategySection.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct StrategySection: View {
    let strategyFolder: URL

    @State private var expandedStrategies = true
    @State private var error: String?
    @State private var folderWatcher: FolderMonitor? = nil
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?

    @State var files: [URL] = []

    var body: some View {
        DisclosureGroup("Strategies", isExpanded: $expandedStrategies) {
            ForEach(files, id: \.self) { file in
                NavigationLink(value: NavigationPath.backtest(backtest: .strategy(url: file))) {
                    StrategyFileRow(fileName: file.lastPathComponent)
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
        .onAppear {
            listWasmFiles()
            Task {
                await watchFolder(folder: strategyFolder)
            }
        }
        .onChange(of: strategyFolder) { _, newValue in
            listWasmFiles()
            Task {
                await watchFolder(folder: newValue)
            }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {
                error = nil
            }
        } message: {
            if let error {
                Text(error)
            }
        }
        .alert("Delete Strategy", isPresented: $showDeleteAlert) {
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

extension StrategySection {
    func deleteFile(_ file: URL) {
        do {
            try FileManager.default.removeItem(at: file)
        } catch {
            self.error = error.localizedDescription
            print("Error deleting file: \(error.localizedDescription)")
        }
    }

    func listWasmFiles() {
        files.removeAll()
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: strategyFolder, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "wasm" {
                    files.append(fileURL)
                }
            }
        } catch {
            self.error = error.localizedDescription
            print("Error listing files: \(error.localizedDescription)")
        }
    }

    func watchFolder(folder: URL) async {
        folderWatcher?.stopMonitoring()
        folderWatcher = FolderMonitor(url: folder)
        for await _ in folderWatcher!.startMonitoring() {
            listWasmFiles()
        }
    }
}
