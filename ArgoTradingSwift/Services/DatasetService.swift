//
//  DatasetService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import Foundation

@Observable
class DatasetService {
    private(set) var datasetFiles: [URL] = []
    private var folderMonitor: FolderMonitor?
    private var monitoringTask: Task<Void, Never>?

    // Callback for when a dataset file is deleted
    var onDatasetDeleted: ((_ deletedURL: URL) -> Void)?

    func setDataFolder(_ folder: URL?) {
        monitoringTask?.cancel()
        folderMonitor?.stopMonitoring()

        guard let folder else {
            datasetFiles = []
            return
        }

        loadFiles(from: folder)
        startMonitoring(folder: folder)
    }

    private func loadFiles(from folder: URL) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
            datasetFiles = fileURLs
                .filter { $0.pathExtension == "parquet" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Error listing dataset files: \(error.localizedDescription)")
            datasetFiles = []
        }
    }

    private func startMonitoring(folder: URL) {
        folderMonitor = FolderMonitor(url: folder)
        monitoringTask = Task { @MainActor in
            guard let monitor = folderMonitor else { return }
            for await _ in monitor.startMonitoring() {
                loadFiles(from: folder)
            }
        }
    }

    func deleteFile(_ file: URL) throws {
        // Notify listeners before deletion
        onDatasetDeleted?(file)
        try FileManager.default.removeItem(at: file)
        // FolderMonitor will trigger reload automatically
    }
}
