//
//  BacktestService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import ArgoTrading
import SwiftUI
import Yams

@Observable
class BacktestService: NSObject, SwiftargoArgoHelperProtocol {
    var currentBacktestTab: BacktestTabs = .general

    // Service references
    var toolbarStatusService: ToolbarStatusService?

    // Engine and task management
    var argoEngine: SwiftargoArgo?
    var backtestTask: Task<Void, Never>?
    var isRunning: Bool = false

    // Progress tracking
    var totalStrategies: Int = 0
    var totalConfigs: Int = 0
    var totalDataFiles: Int = 0
    var totalDataPoints: Int = 0
    var currentStrategy: String = ""
    var currentDataFile: String = ""
    var currentProgress: Progress = .init(current: 0, total: 0)

    func getBacktestEngineConfigSchema() throws -> String {
        let schema = SwiftargoGetBacktestEngineConfigSchema()
        return schema
    }

    // MARK: - SwiftArgoHelper Methods

    func runBacktest(
        schema: Schema,
        datasetURL: URL,
        strategyFolder: URL,
        resultFolder: URL,
        toolbarStatusService: ToolbarStatusService
    ) async {
        self.toolbarStatusService = toolbarStatusService
        isRunning = true

        // Create SwiftargoArgo instance with self as helper
        var argoError: NSError?
        argoEngine = SwiftargoNewArgo(self, &argoError)

        if let argoError = argoError {
            isRunning = false
            Task {
                await toolbarStatusService.setStatus(.error(
                    label: "Backtest",
                    errors: [argoError.localizedDescription],
                    at: Date()
                ))
            }
            return
        }

        do {
            // Set data path to the single selected dataset file
            let datasetURL = datasetURL.toPathStringWithoutFilePrefix()
            try argoEngine?.setDataPath(datasetURL)
            // Create config with strategy path and schema parameters
            let configs = SwiftargoStringArray()
            if let configJSON = String(data: schema.parameters, encoding: .utf8) {
                _ = configs.add(configJSON)
            }
            try argoEngine?.setConfigContent(configs)
        } catch {
            isRunning = false
            Task {
                await toolbarStatusService.setStatus(.error(
                    label: "Backtest",
                    errors: [error.localizedDescription],
                    at: Date()
                ))
            }
            return
        }

        // Run in background task
        backtestTask = Task.detached { [weak self, strategyFolder, resultFolder] in
            guard let self = self else { return }
            do {
                // Convert JSON config to YAML using Yams
                let configDict = (try? JSONSerialization.jsonObject(with: schema.backtestEngineConfig) as? [String: Any]) ?? [:]
                let config = (try? Yams.dump(object: configDict)) ?? ""

                let absoluteStrategyPath = strategyFolder.appendingPathComponent(schema.strategyPath).toPathStringWithoutFilePrefix()

                try self.argoEngine?.run(config, strategyPath: absoluteStrategyPath, resultsFolderPath: resultFolder.toPathStringWithoutFilePrefix())
            } catch {
                if !error.isContextCancelled {
                    await MainActor.run {
                        self.isRunning = false
                    }
                    await self.toolbarStatusService?.setStatus(.error(
                        label: "Backtest",
                        errors: [error.localizedDescription],
                        at: Date()
                    ))
                }
            }
        }
    }

    func cancel() {
        _ = argoEngine?.cancel()
        Task { @MainActor in
            self.argoEngine = nil
            self.backtestTask?.cancel()
            self.backtestTask = nil
            self.isRunning = false
        }
    }

    // MARK: - SwiftargoArgoHelperProtocol

    func onBacktestStart(_ totalStrategies: Int, totalConfigs: Int, totalDataFiles: Int) throws {
        Task { @MainActor in
            self.totalStrategies = totalStrategies
            self.totalConfigs = totalConfigs
            self.totalDataFiles = totalDataFiles
            self.totalDataPoints = totalStrategies * totalConfigs * totalDataFiles
            self.isRunning = true
            self.toolbarStatusService?.setStatusImmediately(.backtesting(
                label: "Starting backtest...",
                progress: Progress(current: 0, total: max(self.totalDataPoints, 1))
            ))
        }
    }

    func onBacktestEnd(_ err: (any Error)?) {
        Task { @MainActor in
            self.isRunning = false
            self.argoEngine = nil
            self.backtestTask = nil

            if let err = err {
                if !err.isContextCancelled {
                    await self.toolbarStatusService?.setStatus(.error(
                        label: "Backtest",
                        errors: [err.localizedDescription],
                        at: Date()
                    ))
                } else {
                    await self.toolbarStatusService?.setStatus(.idle)
                }
            } else {
                await self.toolbarStatusService?.setStatus(.finished(
                    message: "Backtest completed",
                    at: Date()
                ))
            }
        }
    }

    func onStrategyStart(_ strategyIndex: Int, strategyName: String?, totalStrategies: Int) throws {
        Task { @MainActor in
            self.currentStrategy = strategyName ?? "Strategy \(strategyIndex + 1)"
            self.toolbarStatusService?.setStatusImmediately(.backtesting(
                label: "Running \(self.currentStrategy)",
                progress: self.currentProgress
            ))
        }
    }

    func onStrategyEnd(_ strategyIndex: Int, strategyName: String?) {
        // Log completion, next onStrategyStart or onBacktestEnd will update toolbar
    }

    func onRunStart(
        _ runID: String?,
        configIndex: Int,
        configName: String?,
        dataFileIndex: Int,
        dataFilePath: String?,
        totalDataPoints: Int
    ) throws {
        Task { @MainActor in
            self.currentDataFile = URL(fileURLWithPath: dataFilePath ?? "").lastPathComponent
            self.toolbarStatusService?.setStatusImmediately(.backtesting(
                label: "\(self.currentDataFile)",
                progress: self.currentProgress
            ))
        }
    }

    func onRunEnd(
        _ configIndex: Int,
        configName: String?,
        dataFileIndex: Int,
        dataFilePath: String?,
        resultFolderPath: String?
    ) {
        // Log completion, next onRunStart or onBacktestEnd will update
    }

    func onProcessData(_ current: Int, total: Int) throws {
        Task { @MainActor in
            self.currentProgress = Progress(current: current, total: total)
            self.toolbarStatusService?.setStatusImmediately(.backtesting(
                label: self.currentStrategy,
                progress: self.currentProgress
            ))
        }
    }
}
