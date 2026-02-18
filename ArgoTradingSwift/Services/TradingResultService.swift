//
//  TradingResultService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation
import Yams

@Observable
class TradingResultService {
    private(set) var resultsByDate: [String: [TradingResultItem]] = [:]
    private(set) var sortedDates: [String] = []
    private var allResultItems: [String: TradingResultItem] = [:]

    var chartScrollRequest: ChartScrollRequest?

    private var folderMonitor: FolderMonitor?
    private var monitoringTask: Task<Void, Never>?
    private var currentResultFolder: URL?

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func setResultFolder(_ folder: URL?) {
        monitoringTask?.cancel()
        folderMonitor?.stopMonitoring()
        currentResultFolder = folder

        guard let folder else {
            resultsByDate = [:]
            sortedDates = []
            allResultItems = [:]
            return
        }

        Task { @MainActor in
            await loadResults(from: folder)
        }
        startMonitoring(folder: folder)
    }

    func getResultItem(for statsFileURL: URL) -> TradingResultItem? {
        allResultItems.values.first { $0.statsFileURL == statsFileURL }
    }

    /// Request the chart to scroll to a specific timestamp
    func scrollChartToTimestamp(_ timestamp: Date, dataFilePath: String) {
        chartScrollRequest = ChartScrollRequest(timestamp: timestamp, dataFilePath: dataFilePath)
    }

    /// Clear the current scroll request
    func clearScrollRequest() {
        chartScrollRequest = nil
    }

    /// Delete a result item by removing its containing folder
    func deleteResult(_ resultItem: TradingResultItem) throws {
        let folderToDelete = resultItem.statsFileURL.deletingLastPathComponent()

        guard fileManager.fileExists(atPath: folderToDelete.path) else {
            throw TradingResultError.folderNotFound
        }

        try fileManager.removeItem(at: folderToDelete)
    }

    @MainActor
    private func loadResults(from folder: URL) async {
        let statsFiles = findStatsFiles(in: folder)
        var newResultsByDate: [String: [TradingResultItem]] = [:]
        var newAllResultItems: [String: TradingResultItem] = [:]

        for statsFile in statsFiles {
            do {
                let item = try parseStatsFile(at: statsFile)
                newAllResultItems[item.id] = item

                let dateKey = item.result.date
                if newResultsByDate[dateKey] == nil {
                    newResultsByDate[dateKey] = []
                }
                newResultsByDate[dateKey]?.append(item)
            } catch {
                print("Error parsing trading stats file \(statsFile.path): \(error)")
            }
        }

        // Sort results within each date group by session start (newest first)
        for (date, items) in newResultsByDate {
            newResultsByDate[date] = items.sorted { $0.result.sessionStart > $1.result.sessionStart }
        }

        self.resultsByDate = newResultsByDate
        self.sortedDates = newResultsByDate.keys.sorted(by: >)
        self.allResultItems = newAllResultItems
    }

    private func findStatsFiles(in folder: URL) -> [URL] {
        guard fileManager.fileExists(atPath: folder.path) else {
            return []
        }

        var statsFiles: [URL] = []

        if let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent == "stats.yaml" {
                    statsFiles.append(fileURL)
                }
            }
        }

        return statsFiles
    }

    private func parseStatsFile(at url: URL) throws -> TradingResultItem {
        let yamlString = try String(contentsOf: url, encoding: .utf8)
        let decoder = YAMLDecoder()
        let result = try decoder.decode(TradingResult.self, from: yamlString)

        return TradingResultItem(
            result: result,
            statsFileURL: url
        )
    }

    @MainActor
    func reloadResults() {
        guard let folder = currentResultFolder else { return }
        Task {
            await loadResults(from: folder)
        }
    }

    private func startMonitoring(folder: URL) {
        folderMonitor = FolderMonitor(url: folder)
        monitoringTask = Task { @MainActor in
            guard let monitor = folderMonitor else { return }
            for await event in monitor.startMonitoring() {
                switch event {
                case .fileCreated(let url) where url.lastPathComponent == "stats.yaml":
                    // New run appeared — reload
                    await loadResults(from: folder)
                case .fileDeleted(let url) where url.lastPathComponent == "stats.yaml":
                    // Run was deleted — reload
                    await loadResults(from: folder)
                case .folderDeleted, .folderRecreated:
                    await loadResults(from: folder)
                default:
                    // Skip reload for parquet writes, stats.yaml modifications, etc.
                    break
                }
            }
        }
    }
}

enum TradingResultError: LocalizedError {
    case folderNotFound

    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Trading result folder not found"
        }
    }
}
