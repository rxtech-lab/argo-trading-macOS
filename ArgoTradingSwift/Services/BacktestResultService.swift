//
//  BacktestResultService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation
import Yams

@Observable
class BacktestResultService {
    private(set) var resultsByDate: [Date: [BacktestResultItem]] = [:]
    private(set) var sortedDates: [Date] = []
    private var allResultItems: [UUID: BacktestResultItem] = [:]

    private var folderMonitor: FolderMonitor?
    private var monitoringTask: Task<Void, Never>?
    private var currentResultFolder: URL?

    private let fileManager: FileManager

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

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

    func getResultItem(for statsFileURL: URL) -> BacktestResultItem? {
        allResultItems.values.first { $0.statsFileURL == statsFileURL }
    }

    @MainActor
    private func loadResults(from folder: URL) async {
        let statsFiles = findStatsFiles(in: folder)
        var newResultsByDate: [Date: [BacktestResultItem]] = [:]
        var newAllResultItems: [UUID: BacktestResultItem] = [:]

        for statsFile in statsFiles {
            do {
                let resultItems = try parseStatsFile(at: statsFile)
                for item in resultItems {
                    newAllResultItems[item.id] = item

                    // Group by date only (strip time component)
                    let dateOnly = Calendar.current.startOfDay(for: item.runTimestamp)
                    if newResultsByDate[dateOnly] == nil {
                        newResultsByDate[dateOnly] = []
                    }
                    newResultsByDate[dateOnly]?.append(item)
                }
            } catch {
                print("Error parsing stats file \(statsFile.path): \(error)")
            }
        }

        // Sort results within each date group by timestamp (newest first)
        for (date, items) in newResultsByDate {
            newResultsByDate[date] = items.sorted { $0.runTimestamp > $1.runTimestamp }
        }

        await MainActor.run {
            self.resultsByDate = newResultsByDate
            self.sortedDates = newResultsByDate.keys.sorted(by: >)
            self.allResultItems = newAllResultItems
        }
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

    private func parseStatsFile(at url: URL) throws -> [BacktestResultItem] {
        let yamlString = try String(contentsOf: url, encoding: .utf8)
        let decoder = YAMLDecoder()
        let results = try decoder.decode([BacktestResult].self, from: yamlString)

        // Extract timestamp from folder path
        // Path format: .../result/20251227_092739/config_0/BTCUSDT_2022-12-31_2025-12-22_30_minute/stats.yaml
        let pathComponents = url.pathComponents
        var timestamp: Date?
        var datasetFolderName: String?

        // Find timestamp folder (format: yyyyMMdd_HHmmss)
        for (index, component) in pathComponents.enumerated() {
            if let parsedTimestamp = Self.timestampFormatter.date(from: component) {
                timestamp = parsedTimestamp
            }
            // The dataset folder is the parent of stats.yaml
            if component == "stats.yaml", index > 0 {
                datasetFolderName = pathComponents[index - 1]
            }
        }

        guard let runTimestamp = timestamp else {
            throw BacktestResultError.invalidTimestamp
        }

        // Parse the dataset folder name using ParquetFileNameParser
        let parsedFileName = datasetFolderName.flatMap { ParquetFileNameParser.parse($0) }

        return results.map { result in
            BacktestResultItem(
                result: result,
                statsFileURL: url,
                runTimestamp: runTimestamp,
                parsedFileName: parsedFileName
            )
        }
    }

    private func startMonitoring(folder: URL) {
        folderMonitor = FolderMonitor(url: folder)
        monitoringTask = Task { @MainActor in
            guard let monitor = folderMonitor else { return }
            for await _ in monitor.startMonitoring() {
                print("Folder change detected, reloading results...")
                await loadResults(from: folder)
            }
        }
    }
}

enum BacktestResultError: LocalizedError {
    case invalidTimestamp
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidTimestamp:
            return "Could not parse timestamp from folder path"
        case .parsingFailed:
            return "Failed to parse stats.yaml file"
        }
    }
}
