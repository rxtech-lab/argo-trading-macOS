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
    // Service references
    var toolbarStatusService: ToolbarStatusService?
    var strategyCacheService: StrategyCacheService?

    // Engine and task management
    var argoEngine: SwiftargoArgo?
    var backtestTask: Task<Void, Never>?
    var isRunning: Bool = false

    // Current strategy being run
    var currentStrategyId: String?

    // Progress tracking
    var totalStrategies: Int = 0
    var totalConfigs: Int = 0
    var totalDataFiles: Int = 0
    var totalDataPoints: Int = 0
    var currentStrategy: String = ""
    var currentDataFile: String = ""
    var currentProgress: Progress = .init(current: 0, total: 0)

    // Error accumulation
    var accumulatedErrors: [String] = []

    private func appendError(_ error: String) {
        Task { @MainActor in
            self.accumulatedErrors.append(error)
        }
    }

    func getBacktestEngineConfigSchema() throws -> String {
        let schema = SwiftargoGetBacktestEngineConfigSchema()
        return schema
    }

    func getLiveTradingEngineConfigSchema() -> String {
        return SwiftargoGetLiveTradingEngineConfigSchema()
    }

    // MARK: - SwiftArgoHelper Methods

    func runBacktest(
        schema: Schema,
        datasetURL: URL,
        strategyFolder: URL,
        resultFolder: URL,
        toolbarStatusService: ToolbarStatusService,
        strategyCacheService: StrategyCacheService?,
        keychainService: KeychainService? = nil
    ) async {
        self.toolbarStatusService = toolbarStatusService
        self.strategyCacheService = strategyCacheService
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

            // Resolve keychain placeholders in config before passing to engine
            var configData = schema.parameters
            if schema.hasKeychainFields, let keychainService = keychainService {
                configData = await resolveKeychainPlaceholders(
                    parameters: schema.parameters,
                    schemaId: schema.id.uuidString,
                    keychainFieldNames: schema.keychainFieldNames,
                    keychainService: keychainService
                )
            }

            // Create config with strategy path and schema parameters
            let configs = SwiftargoStringArray()
            if let configJSON = String(data: configData, encoding: .utf8) {
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

        // Load strategy ID from metadata before running (using cache if available)
        let strategyURL = strategyFolder.appendingPathComponent(schema.strategyPath)
        if let cacheService = strategyCacheService,
           let metadata = try? await cacheService.getMetadata(for: strategyURL)
        {
            currentStrategyId = metadata.identifier
        } else if let strategyApi = SwiftargoStrategyApi(),
                  let metadata = try? strategyApi.getStrategyMetadata(strategyURL.toPathStringWithoutFilePrefix())
        {
            currentStrategyId = metadata.identifier
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

    private func resolveKeychainPlaceholders(
        parameters: Data,
        schemaId: String,
        keychainFieldNames: [String],
        keychainService: KeychainService
    ) async -> Data {
        let authenticated = await keychainService.authenticateWithBiometrics()
        guard authenticated else { return parameters }

        let values = keychainService.loadKeychainValues(
            identifier: schemaId,
            fieldNames: Set(keychainFieldNames)
        )

        guard !values.isEmpty,
              var dict = try? JSONSerialization.jsonObject(with: parameters) as? [String: Any]
        else { return parameters }

        for (field, value) in values {
            if let existing = dict[field] as? String, existing == "__KEYCHAIN__" {
                dict[field] = value
            }
        }

        return (try? JSONSerialization.data(withJSONObject: dict)) ?? parameters
    }

    @MainActor
    func cancel() async {
        _ = argoEngine?.cancel()
        argoEngine = nil
        backtestTask?.cancel()
        backtestTask = nil
        isRunning = false
        currentStrategyId = nil
    }

    // MARK: - SwiftargoArgoHelperProtocol

    func onBacktestStart(_ totalStrategies: Int, totalConfigs: Int, totalDataFiles: Int) throws {
        Task { @MainActor in
            self.accumulatedErrors = []
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
            self.currentStrategyId = nil

            // Combine passed error with accumulated errors
            var allErrors = self.accumulatedErrors
            if let err = err, !err.isContextCancelled {
                allErrors.append(err.localizedDescription)
            }

            if !allErrors.isEmpty {
                await self.toolbarStatusService?.setStatus(.error(
                    label: "Backtest",
                    errors: allErrors,
                    at: Date()
                ))
            } else if err?.isContextCancelled == true {
                await self.toolbarStatusService?.setStatus(.idle)
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
