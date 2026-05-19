//
//  TradingService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import ArgoTrading
import Foundation
import LightweightChart
import UserNotifications

enum LiveTradingDataCategory: String, CaseIterable, Hashable {
    case marketData = "market_data"
    case trades
    case orders
    case marks
    case logs
    case stats
}

struct LiveTradingDataChange: Equatable {
    let runID: String
    let categories: Set<LiveTradingDataCategory>
    let finalized: Bool
    let sequence: Int64

    func contains(_ category: LiveTradingDataCategory) -> Bool {
        finalized || categories.contains(category)
    }
}

@Observable
class TradingService: NSObject, SwiftargoTradingEngineHelperProtocol {
    // Service references
    var toolbarStatusService: ToolbarStatusService?
    weak var walletService: WalletService?

    // Engine and task management
    var tradingEngine: SwiftargoTradingEngine?
    var tradingTask: Task<Void, Never>?
    var isRunning: Bool = false

    // Symbols reported by the engine on start (used for wallet historical-orders queries)
    var currentSymbols: [String] = []

    // Wallet-only engine: a minimal engine configured with only the trading
    // provider (no market data, no strategy, no Run loop). Lets the wallet UI
    // call into Wallet() without requiring a full live trading session.
    var walletEngine: SwiftargoTradingEngine?
    private var walletEngineProviderID: UUID?

    /// Engine that the wallet UI should query against — prefers the live
    /// trading engine when running, falls back to the wallet-only engine.
    var walletAccessibleEngine: SwiftargoTradingEngine? {
        tradingEngine ?? walletEngine
    }

    // Live chart data — populated from OnMarketData callbacks
    var liveChartData: [PriceData] = []
    var baseInterval: ChartTimeInterval = .oneSecond
    private var candleCount: Int = 0
    var liveDataChange: LiveTradingDataChange?
    private var latestLiveDataSequenceByRunID: [String: Int64] = [:]

    // Active run tracking
    var activeRunId: String?
    private var currentTradingLabel: String = "Trading"
    private var currentTradingPhase: String = "Starting"
    private var currentMarketDataStatus: String?
    private var currentProviderTradingStatus: String?
    private var currentProviderProblemMessage: String?

    // Error tracking
    var lastError: String?

    private static var hasRequestedNotificationAuthorization = false

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

        // Tear down any wallet-only engine so it doesn't compete with the
        // live engine over the same provider configuration.
        disconnectWalletEngine()

        self.toolbarStatusService = toolbarStatusService
        isRunning = true
        liveChartData = []
        baseInterval = .oneSecond
        candleCount = 0
        lastError = nil
        currentTradingLabel = provider.name
        currentTradingPhase = "Starting"
        currentMarketDataStatus = nil
        currentProviderTradingStatus = nil
        currentProviderProblemMessage = nil

        await toolbarStatusService.setStatus(.trading(
            label: provider.name,
            phase: currentTradingPhase,
            progress: nil,
            message: nil
        ))

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

            // Set strategy config — resolve keychain placeholders, pass JSON through
            var strategyConfigData = schema.parameters
            if schema.hasKeychainFields {
                strategyConfigData = resolveKeychainPlaceholders(
                    parameters: schema.parameters,
                    identifier: schema.id.uuidString,
                    keychainFieldNames: schema.keychainFieldNames,
                    keychainService: keychainService
                )
            }
            let jsonString = String(data: strategyConfigData, encoding: .utf8) ?? "{}"
            try tradingEngine?.setStrategyConfig(jsonString)

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
        currentSymbols = []
        walletService?.clear()
        currentTradingPhase = "Stopped"

        await toolbarStatusService.setStatus(.idle)
    }

    // MARK: - Wallet-only engine

    /// Creates (or reuses) a minimal engine bound to the given trading provider
    /// so the wallet UI can fetch balances and orders without a live trading
    /// session. Returns true if the wallet engine is ready to serve requests.
    @MainActor
    func connectWalletProvider(
        provider: TradingProvider,
        keychainService: KeychainService
    ) async -> Bool {
        // Live engine already covers wallet queries — nothing to do.
        if tradingEngine != nil { return true }

        // Already connected to the same provider.
        if walletEngine != nil, walletEngineProviderID == provider.id {
            return true
        }

        // Different provider — tear down the previous wallet engine.
        disconnectWalletEngine()

        let success = await keychainService.authenticateWithBiometrics()
        guard success else { return false }

        var engineError: NSError?
        let engine = SwiftargoNewTradingEngine(self, &engineError)
        if let engineError {
            logger.error("Wallet engine create failed: \(engineError.localizedDescription)")
            return false
        }
        guard let engine else { return false }

        do {
            try engine.initialize("{}")

            let tradingKeychainFields = getTradingProviderKeychainFieldNames(provider: provider)
            let tradingConfigData = resolveKeychainPlaceholders(
                parameters: provider.tradingSystemConfig,
                identifier: provider.id.uuidString,
                keychainFieldNames: tradingKeychainFields,
                keychainService: keychainService
            )
            guard let tradingConfigJSON = String(data: tradingConfigData, encoding: .utf8) else {
                return false
            }
            try engine.setTradingProvider(provider.tradingSystemProvider, configJSON: tradingConfigJSON)
        } catch {
            logger.error("Wallet engine setTradingProvider failed: \(error.localizedDescription)")
            return false
        }

        walletEngine = engine
        walletEngineProviderID = provider.id
        return true
    }

    @MainActor
    func disconnectWalletEngine() {
        _ = walletEngine?.cancel()
        walletEngine = nil
        walletEngineProviderID = nil
        walletService?.clear()
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
        var symbolValues: [String] = []
        if let symbols {
            for index in 0 ..< symbols.size() {
                symbolValues.append(symbols.get(index))
            }
        }

        Task { @MainActor in
            self.currentSymbols = symbolValues
            if let interval = interval, let parsed = ChartTimeInterval(rawValue: interval) {
                self.baseInterval = parsed
            }
        }
    }

    func onEngineStop(_ err: (any Error)?) {
        Task { @MainActor in
            self.isRunning = false
            self.tradingEngine = nil
            self.tradingTask = nil
            self.currentSymbols = []
            self.walletService?.clear()
            self.currentTradingPhase = "Stopped"

            if let err = err, !err.isContextCancelled {
                self.lastError = err.localizedDescription
                await self.toolbarStatusService?.setStatus(.error(
                    label: "Trading",
                    errors: [err.localizedDescription],
                    at: Date()
                ))
            } else if let providerProblemMessage = self.currentProviderProblemMessage {
                self.toolbarStatusService?.setStatusImmediately(.trading(
                    label: self.currentTradingLabel,
                    phase: self.currentTradingPhase,
                    progress: nil,
                    message: providerProblemMessage
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

    func onLiveDataChanged(
        _ runId: String?,
        categories: (any SwiftargoStringCollectionProtocol)?,
        finalized: Bool,
        sequence: Int64
    ) throws {
        var categoryValues: [String] = []
        if let categories {
            for index in 0 ..< categories.size() {
                categoryValues.append(categories.get(index))
            }
        }

        Task { @MainActor in
            self.recordLiveDataChanged(
                runId: runId,
                categories: categoryValues,
                finalized: finalized,
                sequence: sequence
            )
        }
    }

    @MainActor
    func recordLiveDataChanged(
        runId: String?,
        categories categoryValues: [String],
        finalized: Bool,
        sequence: Int64
    ) {
        guard let runId, !runId.isEmpty else { return }

        var categories = Set(categoryValues.compactMap(LiveTradingDataCategory.init(rawValue:)))
        if finalized, categories.isEmpty {
            categories = Set(LiveTradingDataCategory.allCases)
        }
        guard finalized || !categories.isEmpty else { return }

        let latestSequence = latestLiveDataSequenceByRunID[runId] ?? .min
        guard sequence > latestSequence else { return }

        latestLiveDataSequenceByRunID[runId] = sequence
        liveDataChange = LiveTradingDataChange(
            runID: runId,
            categories: categories,
            finalized: finalized,
            sequence: sequence
        )
    }

    func onOrderPlaced(_ orderJSON: String?) throws {
        Task {
            await sendOrderPlacedNotification(orderJSON)
        }
    }

    func onOrderFilled(_ orderJSON: String?) throws {
        // Fills are tracked on disk by the engine
    }

    func onError(_ err: (any Error)?) {
        Task { @MainActor in
            if let err = err {
                let message = err.localizedDescription
                self.lastError = message
                self.currentTradingPhase = "Provider error"
                self.currentProviderProblemMessage = message
                self.toolbarStatusService?.setStatusImmediately(.trading(
                    label: self.currentTradingLabel,
                    phase: self.currentTradingPhase,
                    progress: nil,
                    message: message
                ))
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

    func onStatusUpdate(_ status: String?) throws {
        Task { @MainActor in
            let phase = self.liveTradingPhaseLabel(for: status)

            if status == "stopped" {
                if let providerProblemMessage = self.currentProviderProblemMessage {
                    self.toolbarStatusService?.setStatusImmediately(.trading(
                        label: self.currentTradingLabel,
                        phase: self.currentTradingPhase,
                        progress: nil,
                        message: providerProblemMessage
                    ))
                    return
                }

                self.currentTradingPhase = phase
                self.currentProviderProblemMessage = nil
                await self.toolbarStatusService?.setStatus(.idle)
                return
            }

            if let providerProblemMessage = self.currentProviderProblemMessage {
                self.toolbarStatusService?.setStatusImmediately(.trading(
                    label: self.currentTradingLabel,
                    phase: self.currentTradingPhase,
                    progress: nil,
                    message: providerProblemMessage
                ))
                return
            }

            self.currentTradingPhase = phase
            self.toolbarStatusService?.setStatusImmediately(.trading(
                label: self.currentTradingLabel,
                phase: phase,
                progress: nil,
                message: nil
            ))
        }
    }

    func onPrefetchProgress(_ symbol: String?, current: Double, total: Double, message: String?) throws {
        Task { @MainActor in
            let label: String
            if let symbol, !symbol.isEmpty {
                label = symbol
            } else {
                label = self.currentTradingLabel
            }
            let currentCount = max(Int(current.rounded()), 0)
            let totalCount = max(Int(total.rounded()), 1)
            let progress = Progress(current: currentCount, total: totalCount)

            self.toolbarStatusService?.setStatusImmediately(.trading(
                label: label,
                phase: self.currentTradingPhase,
                progress: progress,
                message: message
            ))
        }
    }

    func onOrderChanged() throws {
        notifyWalletStale()
    }

    func onBalanceChanged() throws {
        notifyWalletStale()
    }

    func onBuyingPowerChanged() throws {
        notifyWalletStale()
    }

    func onAssetsChanged() throws {
        notifyWalletStale()
    }

    private func notifyWalletStale() {
        Task { @MainActor in
            guard let walletService = self.walletService else { return }
            let currency = WalletDisplayPreferences.currentCurrency
            walletService.scheduleRefresh(baseCurrency: currency)
        }
    }

    func onProviderStatusChange(_ marketDataStatus: String?, tradingStatus: String?) throws {
        Task { @MainActor in
            self.currentMarketDataStatus = marketDataStatus
            self.currentProviderTradingStatus = tradingStatus

            let phase = self.providerStatusPhase(
                marketDataStatus: marketDataStatus,
                tradingStatus: tradingStatus
            )
            self.currentTradingPhase = phase
            let message = self.providerStatusMessage(
                marketDataStatus: marketDataStatus,
                tradingStatus: tradingStatus
            )
            self.currentProviderProblemMessage = self.isDisconnected(marketDataStatus) || self.isDisconnected(tradingStatus)
                ? message
                : nil

            self.toolbarStatusService?.setStatusImmediately(.trading(
                label: self.currentTradingLabel,
                phase: phase,
                progress: nil,
                message: message
            ))
        }
    }

    private func liveTradingPhaseLabel(for status: String?) -> String {
        switch status {
        case "prefetching":
            return "Prefetching"
        case "gap_filling":
            return "Gap filling"
        case "running":
            return "Running"
        case "stopped":
            return "Stopped"
        case let status? where !status.isEmpty:
            return status
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        default:
            return "Running"
        }
    }

    private func providerStatusPhase(marketDataStatus: String?, tradingStatus: String?) -> String {
        if isDisconnected(tradingStatus) || isDisconnected(marketDataStatus) {
            return "Disconnected"
        }

        if isConnected(tradingStatus) || isConnected(marketDataStatus) {
            return "Connected"
        }

        return currentTradingPhase
    }

    private func providerStatusMessage(marketDataStatus: String?, tradingStatus: String?) -> String {
        let marketDataDisconnected = isDisconnected(marketDataStatus)
        let tradingDisconnected = isDisconnected(tradingStatus)

        if marketDataDisconnected && tradingDisconnected {
            return "Providers disconnected"
        }

        if tradingDisconnected {
            return "Trading provider disconnected"
        }

        if marketDataDisconnected {
            return "Market data disconnected"
        }

        if isConnected(marketDataStatus) && isConnected(tradingStatus) {
            return "Providers connected"
        }

        if isConnected(tradingStatus) {
            return "Trading provider connected"
        }

        if isConnected(marketDataStatus) {
            return "Market data connected"
        }

        return "Provider status updated"
    }

    private func isConnected(_ status: String?) -> Bool {
        status?.localizedCaseInsensitiveCompare("connected") == .orderedSame
    }

    private func isDisconnected(_ status: String?) -> Bool {
        status?.localizedCaseInsensitiveCompare("disconnected") == .orderedSame
    }

    private func sendOrderPlacedNotification(_ orderJSON: String?) async {
        guard let orderJSON, let data = orderJSON.data(using: .utf8) else {
            return
        }

        let order: LiveOrderNotificationPayload
        do {
            order = try JSONDecoder().decode(LiveOrderNotificationPayload.self, from: data)
        } catch {
            logger.warning("Failed to decode order notification payload: \(error.localizedDescription)")
            return
        }

        do {
            try await requestNotificationAuthorizationIfNeeded()
        } catch {
            logger.warning("Failed to request notification authorization: \(error.localizedDescription)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Order placed: \(order.actionLabel) \(order.symbol)"
        content.body = order.notificationBody(placedAt: Date())
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "live-order-placed-\(order.id)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.warning("Failed to send order placed notification: \(error.localizedDescription)")
        }
    }

    private func requestNotificationAuthorizationIfNeeded() async throws {
        guard !Self.hasRequestedNotificationAuthorization else {
            return
        }

        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        Self.hasRequestedNotificationAuthorization = true
    }
}

private struct LiveOrderNotificationPayload: Decodable {
    let id: String
    let symbol: String
    let side: String
    let orderType: String
    let price: Double
    let quantity: Double

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case side
        case orderType = "order_type"
        case price
        case quantity
    }

    var actionLabel: String {
        side.uppercased()
    }

    func notificationBody(placedAt: Date) -> String {
        [
            "Time: \(Self.timeFormatter.string(from: placedAt))",
            "Symbol: \(symbol)",
            "Price: \(Self.numberFormatter.string(from: NSNumber(value: price)) ?? "\(price)")",
            "Amount: \(Self.numberFormatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)")",
            "Action: \(actionLabel) \(orderType.uppercased())"
        ].joined(separator: "\n")
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter
    }()
}
