//
//  TradingService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import ArgoTrading
import Foundation
import LightweightChart
import Yams

@Observable
class TradingService: NSObject, SwiftargoTradingEngineHelperProtocol {
    // Service references
    var toolbarStatusService: ToolbarStatusService?

    // Engine and task management
    var tradingEngine: SwiftargoTradingEngine?
    var tradingTask: Task<Void, Never>?
    var isRunning: Bool = false

    // Live chart data — populated from OnMarketData callbacks
    var liveChartData: [PriceData] = []
    var baseInterval: ChartTimeInterval = .oneSecond
    private var candleCount: Int = 0

    // Active run tracking
    var activeRunId: String?

    // Error tracking
    var lastError: String?

    // MARK: - Start/Stop

    @MainActor
    func startTrading(
        provider: TradingProvider,
        schema: Schema,
        strategyFolder: URL,
        tradingResultFolder: URL,
        keychainService: KeychainService,
        toolbarStatusService: ToolbarStatusService
    ) async {
        let success = await keychainService.authenticateWithBiometrics()
        guard success else { return }

        self.toolbarStatusService = toolbarStatusService
        isRunning = true
        liveChartData = []
        baseInterval = .oneSecond
        candleCount = 0
        lastError = nil

        await toolbarStatusService.setStatus(.trading(label: provider.name))

        // Create engine
        var engineError: NSError?
        tradingEngine = SwiftargoNewTradingEngine(self, &engineError)

        if let engineError = engineError {
            isRunning = false
            await toolbarStatusService.setStatus(.error(
                label: "Trading",
                errors: [engineError.localizedDescription],
                at: Date()
            ))
            return
        }

        do {
            // Initialize engine with live trading engine config from schema
            if let configJSON = String(data: schema.liveTradingEngineConfig, encoding: .utf8),
               !configJSON.isEmpty
            {
                try tradingEngine?.initialize(configJSON)
            } else {
                try tradingEngine?.initialize("{}")
            }

            // Create trading folder if it doesn't exist
            let fileManager = FileManager.default
            let tradingPath = tradingResultFolder.toPathStringWithoutFilePrefix()
            logger.info("Trading result folder: \(tradingPath)")
            try? fileManager.createDirectory(at: tradingResultFolder, withIntermediateDirectories: true)

            // Set data output path - engine handles logs and results subdirectories
            try tradingEngine?.setDataOutputPath(tradingPath)

            // Set market data provider with keychain resolution
            let marketDataKeychainFields = getMarketDataKeychainFieldNames(provider: provider)
            let marketDataConfigData = resolveKeychainPlaceholders(
                parameters: provider.liveTradingEngineConfig,
                identifier: "\(provider.id.uuidString)-marketdata",
                keychainFieldNames: marketDataKeychainFields,
                keychainService: keychainService
            )
            if let marketDataConfigJSON = String(data: marketDataConfigData, encoding: .utf8) {
                logger.info("Market data provider: \(provider.marketDataProvider)")
                logger.info("Market data identifier: \(provider.id.uuidString)-marketdata")
                logger.info("Market data keychain fields: \(marketDataKeychainFields)")
                if let configDict = try? JSONSerialization.jsonObject(with: marketDataConfigData) as? [String: Any] {
                    logger.info("Market data config: \(configDict)")
                }
                try tradingEngine?.setMarketDataProvider(provider.marketDataProvider, configJSON: marketDataConfigJSON)
            }

            // Set trading provider with keychain resolution
            let tradingKeychainFields = getTradingProviderKeychainFieldNames(provider: provider)
            let tradingConfigData = resolveKeychainPlaceholders(
                parameters: provider.tradingSystemConfig,
                identifier: provider.id.uuidString,
                keychainFieldNames: tradingKeychainFields,
                keychainService: keychainService
            )
            if let tradingConfigJSON = String(data: tradingConfigData, encoding: .utf8) {
                logger.info("Trading provider: \(provider.tradingSystemProvider)")
                logger.info("Trading provider identifier: \(provider.id.uuidString)")
                logger.info("Trading provider keychain fields: \(tradingKeychainFields)")
                if let configDict = try? JSONSerialization.jsonObject(with: tradingConfigData) as? [String: Any] {
                    logger.info("Trading config: \(configDict)")
                }
                try tradingEngine?.setTradingProvider(provider.tradingSystemProvider, configJSON: tradingConfigJSON)
            }

            // Set WASM strategy
            let wasmPath = strategyFolder.appendingPathComponent(schema.strategyPath).toPathStringWithoutFilePrefix()
            try tradingEngine?.setWasm(wasmPath)

            // Set strategy config — resolve keychain + convert JSON to YAML
            var strategyConfigData = schema.parameters
            if schema.hasKeychainFields {
                strategyConfigData = resolveKeychainPlaceholders(
                    parameters: schema.parameters,
                    identifier: schema.id.uuidString,
                    keychainFieldNames: schema.keychainFieldNames,
                    keychainService: keychainService
                )
            }
            let configDict = (try? JSONSerialization.jsonObject(with: strategyConfigData) as? [String: Any]) ?? [:]
            let yamlString = (try? Yams.dump(object: configDict)) ?? ""
            try tradingEngine?.setStrategyConfig(yamlString)

            // Run in background — blocking call
            tradingTask = Task.detached { [weak self] in
                guard let self = self else { return }
                do {
                    try self.tradingEngine?.run()
                } catch {
                    if !error.isContextCancelled {
                        Task { @MainActor in
                            self.isRunning = false
                        }
                        await self.toolbarStatusService?.setStatus(.error(
                            label: "Trading",
                            errors: [error.localizedDescription],
                            at: Date()
                        ))
                    }
                }
            }
        } catch {
            isRunning = false
            tradingEngine = nil
            await toolbarStatusService.setStatus(.error(
                label: "Trading",
                errors: [error.localizedDescription],
                at: Date()
            ))
        }
    }

    @MainActor
    func stopTrading(toolbarStatusService: ToolbarStatusService) async {
        _ = tradingEngine?.cancel()
        tradingEngine = nil
        tradingTask?.cancel()
        tradingTask = nil
        isRunning = false
        activeRunId = nil

        await toolbarStatusService.setStatus(.idle)
    }

    // MARK: - Active Run

    @MainActor
    func setActiveRun(_ runId: String?, historicalData: [PriceData] = []) {
        activeRunId = runId
        liveChartData = historicalData
        candleCount = historicalData.count
    }

    // MARK: - Helpers

    private func getMarketDataKeychainFieldNames(provider: TradingProvider) -> [String] {
        if let fields = SwiftargoGetMarketDataProviderKeychainFields(provider.marketDataProvider),
           let stringFields = fields as? SwiftargoStringCollection
        {
            return stringFields.stringArray
        }
        return []
    }

    private func getTradingProviderKeychainFieldNames(provider: TradingProvider) -> [String] {
        if let fields = SwiftargoGetTradingProviderKeychainFields(provider.tradingSystemProvider),
           let stringFields = fields as? SwiftargoStringCollection
        {
            return stringFields.stringArray
        }
        return []
    }

    private func resolveKeychainPlaceholders(
        parameters: Data,
        identifier: String,
        keychainFieldNames: [String],
        keychainService: KeychainService
    ) -> Data {
        guard !keychainFieldNames.isEmpty else {
            logger.info("resolveKeychainPlaceholders: No keychain fields for identifier '\(identifier)'")
            return parameters
        }

        let values = keychainService.loadKeychainValues(
            identifier: identifier,
            fieldNames: Set(keychainFieldNames)
        )

        logger.info("resolveKeychainPlaceholders: identifier='\(identifier)', fields=\(keychainFieldNames), foundValues=\(values)")

        guard !values.isEmpty,
              var dict = try? JSONSerialization.jsonObject(with: parameters) as? [String: Any]
        else {
            logger.warning("resolveKeychainPlaceholders: No keychain values found or failed to parse parameters for identifier '\(identifier)'")
            return parameters
        }

        for (field, value) in values {
            if let existing = dict[field] as? String, existing == "__KEYCHAIN__" {
                dict[field] = value
            }
        }

        return (try? JSONSerialization.data(withJSONObject: dict)) ?? parameters
    }

    // MARK: - SwiftargoTradingEngineHelperProtocol

    func onEngineStart(
        _ symbols: (any SwiftargoStringCollectionProtocol)?,
        interval: String?,
        previousDataPath: String?
    ) throws {
        if let interval = interval, let parsed = ChartTimeInterval(rawValue: interval) {
            Task { @MainActor in
                self.baseInterval = parsed
            }
        }
    }

    func onEngineStop(_ err: (any Error)?) {
        Task { @MainActor in
            self.isRunning = false
            self.tradingEngine = nil
            self.tradingTask = nil

            if let err = err, !err.isContextCancelled {
                self.lastError = err.localizedDescription
                await self.toolbarStatusService?.setStatus(.error(
                    label: "Trading",
                    errors: [err.localizedDescription],
                    at: Date()
                ))
            } else {
                await self.toolbarStatusService?.setStatus(.idle)
            }
        }
    }

    func onMarketData(
        _ runId: String?,
        symbol: String?,
        timestamp: Int64,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) throws {
        // Only append if run_id matches
        guard runId == activeRunId else { return }

        let priceData = PriceData(
            globalIndex: candleCount,
            date: Date(timeIntervalSince1970: Double(timestamp) / 1000.0),
            ticker: symbol ?? "",
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )

        candleCount += 1

        Task { @MainActor in
            self.liveChartData.append(priceData)
        }
    }

    func onOrderPlaced(_ orderJSON: String?) throws {
        // Orders are tracked on disk by the engine
    }

    func onOrderFilled(_ orderJSON: String?) throws {
        // Fills are tracked on disk by the engine
    }

    func onError(_ err: (any Error)?) {
        Task { @MainActor in
            if let err = err {
                self.lastError = err.localizedDescription
            }
        }
    }

    func onStrategyError(_ symbol: String?, timestamp: Int64, err: (any Error)?) {
        Task { @MainActor in
            if let err = err {
                self.lastError = err.localizedDescription
            }
        }
    }
}
