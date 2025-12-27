//
//  BacktestService.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import ArgoTrading
import SwiftUI

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
    ) {
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
                let config = """
                initial_capital: 10000000
                broker: interactive_broker
                start_time: "2025-01-01T00:00:00Z"
                end_time: "2025-04-04T00:00:00Z"
                """

                let absoluteStrategyPath = strategyFolder.appendingPathComponent(schema.strategyPath).toPathStringWithoutFilePrefix()

                try self.argoEngine?.run(config, strategyPath: absoluteStrategyPath, resultsFolderPath: resultFolder.toPathStringWithoutFilePrefix())
            } catch {
                print("Backtest error: \(error)")
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

    func cancel() {
        _ = argoEngine?.cancel()
        argoEngine = nil
        backtestTask?.cancel()
        backtestTask = nil
        isRunning = false
        toolbarStatusService?.setStatusImmediately(.idle)
    }

    // MARK: - SwiftargoArgoHelperProtocol

    func onBacktestStart(_ totalStrategies: Int, totalConfigs: Int, totalDataFiles: Int) throws {
        self.totalStrategies = totalStrategies
        self.totalConfigs = totalConfigs
        self.totalDataFiles = totalDataFiles
        totalDataPoints = totalStrategies * totalConfigs * totalDataFiles
        isRunning = true
        toolbarStatusService?.setStatusImmediately(.backtesting(
            label: "Starting backtest...",
            progress: Progress(current: 0, total: max(totalDataPoints, 1))
        ))
    }

    func onBacktestEnd(_ err: (any Error)?) {
        isRunning = false
        argoEngine = nil
        backtestTask = nil

        Task {
            if let err = err {
                await toolbarStatusService?.setStatus(.error(
                    label: "Backtest",
                    errors: [err.localizedDescription],
                    at: Date()
                ))
            } else {
                await toolbarStatusService?.setStatus(.finished(
                    message: "Backtest completed",
                    at: Date()
                ))
            }
        }
    }

    func onStrategyStart(_ strategyIndex: Int, strategyName: String?, totalStrategies: Int) throws {
        currentStrategy = strategyName ?? "Strategy \(strategyIndex + 1)"
        toolbarStatusService?.setStatusImmediately(.backtesting(
            label: "Running \(currentStrategy)",
            progress: currentProgress
        ))
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
        currentDataFile = URL(fileURLWithPath: dataFilePath ?? "").lastPathComponent
        toolbarStatusService?.setStatusImmediately(.backtesting(
            label: "\(currentDataFile)",
            progress: currentProgress
        ))
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
        currentProgress = Progress(current: current, total: total)
        toolbarStatusService?.setStatusImmediately(.backtesting(
            label: currentStrategy,
            progress: currentProgress
        ))
    }
}
