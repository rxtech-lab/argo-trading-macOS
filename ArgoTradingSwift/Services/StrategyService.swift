//
//  StrategyService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/24/25.
//

import Foundation

@Observable
class StrategyService {
    private(set) var strategyFiles: [URL] = []
    private var folderMonitor: FolderMonitor?
    private var monitoringTask: Task<Void, Never>?

    // UI State
    var showFileImporter = false
    var error: String?

    // Callback for when a strategy file is renamed
    var onStrategyRenamed: ((_ oldPath: String, _ newPath: String) -> Void)?

    // Callback for when a strategy file is deleted
    var onStrategyDeleted: ((_ strategyPath: String) -> Void)?

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func setStrategyFolder(_ folder: URL?) {
        monitoringTask?.cancel()
        folderMonitor?.stopMonitoring()

        guard let folder else {
            strategyFiles = []
            return
        }

        loadFiles(from: folder)
        startMonitoring(folder: folder)
    }

    private func loadFiles(from folder: URL) {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil
            )
            strategyFiles = fileURLs
                .filter { $0.pathExtension == "wasm" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Error listing strategy files: \(error.localizedDescription)")
            strategyFiles = []
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
        let strategyPath = file.lastPathComponent
        // Notify listeners before deletion
        onStrategyDeleted?(strategyPath)
        try fileManager.removeItem(at: file)
        // FolderMonitor will trigger reload automatically
    }

    func renameFile(_ file: URL, to newName: String) throws {
        let oldPath = file.lastPathComponent
        let newURL = file.deletingLastPathComponent()
            .appendingPathComponent(newName)
            .appendingPathExtension("wasm")
        try fileManager.moveItem(at: file, to: newURL)
        // FolderMonitor will trigger reload automatically

        // Notify listeners about the rename
        onStrategyRenamed?(oldPath, newURL.lastPathComponent)
    }

    func importStrategy(from sourceURL: URL, to destinationFolder: URL) {
        let destURL = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            // Ensure strategy folder exists
            if !fileManager.fileExists(atPath: destinationFolder.path) {
                try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
            }

            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            // Copy file to destination
            try fileManager.copyItem(at: sourceURL, to: destURL)
        } catch {
            self.error = error.localizedDescription
            print("Error importing strategy: \(error.localizedDescription)")
        }
    }

    func clearError() {
        error = nil
    }
}
