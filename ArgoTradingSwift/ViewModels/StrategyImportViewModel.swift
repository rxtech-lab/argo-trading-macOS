//
//  StrategyImportViewModel.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation

@Observable
class StrategyImportViewModel {
    var showFileImporter = false
    var error: String?

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
