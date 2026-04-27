//
//  MCPToolHandlers.swift
//  ArgoTradingSwift
//
//  Per-tool implementations. All run on MainActor because they read and mutate
//  SwiftUI document state via DocumentRegistry.
//

import ArgoTrading
import Foundation
import MCP

enum MCPToolHandlers {
    // MARK: - load_strategy

    @MainActor
    static func loadStrategy(args: [String: Value]) async throws -> CallTool.Result {
        guard let pathValue = args["strategy_path"]?.stringValue, !pathValue.isEmpty else {
            throw MCPToolError.missing("strategy_path")
        }
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let sourceURL = URL(fileURLWithPath: (pathValue as NSString).expandingTildeInPath)
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourceURL.path) else {
            throw MCPToolError.invalid("strategy_path", "file does not exist at \(sourceURL.path)")
        }
        guard sourceURL.pathExtension.lowercased() == "wasm" else {
            throw MCPToolError.invalid("strategy_path", "expected a .wasm file")
        }

        let doc = handle.snapshot()
        let destFolder = doc.strategyFolder
        try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)
        let destURL = destFolder.appendingPathComponent(sourceURL.lastPathComponent)
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        try fm.copyItem(at: sourceURL, to: destURL)

        return .json(.object([
            "status": .string("ok"),
            "destination": .string(destURL.path),
        ]))
    }

    // MARK: - list_schemas

    @MainActor
    static func listSchemas(args: [String: Value]) async throws -> CallTool.Result {
        guard let limit = args["limit"]?.intValue else {
            throw MCPToolError.missing("limit")
        }
        let query = args["query"]?.stringValue
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        let filtered: [Schema]
        if let q = query, !q.isEmpty {
            filtered = doc.schemas.filter { $0.name.range(of: q, options: .caseInsensitive) != nil }
        } else {
            filtered = doc.schemas
        }
        let limited = Array(filtered.prefix(max(0, limit)))
        let schemas: [Value] = limited.map {
            .object([
                "id": .string($0.id.uuidString),
                "name": .string($0.name),
                "created_at": .string(ISO8601DateFormatter().string(from: $0.createdAt)),
            ])
        }
        return .json(.object(["schemas": .array(schemas), "total": .int(filtered.count)]))
    }

    // MARK: - read_schema

    @MainActor
    static func readSchema(args: [String: Value]) async throws -> CallTool.Result {
        let schema = try requireSchema(args: args)
        return .json(.object([
            "id": .string(schema.id.uuidString),
            "name": .string(schema.name),
            "strategy_path": .string(schema.strategyPath),
            "backtest_config": decodeJSONOrNull(schema.backtestEngineConfig),
            "live_trading_config": decodeJSONOrNull(schema.liveTradingEngineConfig),
            "strategy_config": decodeJSONOrNull(schema.parameters),
        ]))
    }

    // MARK: - update_schema

    @MainActor
    static func updateSchema(args: [String: Value]) async throws -> CallTool.Result {
        let existing = try requireSchema(args: args)
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        var updated = existing
        if let backtest = args["backtest_config"] {
            updated.backtestEngineConfig = try encodeJSON(backtest, field: "backtest_config")
        }
        if let live = args["live_trading_config"] {
            updated.liveTradingEngineConfig = try encodeJSON(live, field: "live_trading_config")
        }
        if let strat = args["strategy_config"] {
            updated.parameters = try encodeJSON(strat, field: "strategy_config")
        }
        updated.updatedAt = Date()
        handle.mutate { $0.updateSchema(updated) }
        return .json(.object(["status": .string("ok"), "schema_id": .string(updated.id.uuidString)]))
    }

    // MARK: - list_data

    @MainActor
    static func listData(args: [String: Value]) async throws -> CallTool.Result {
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: doc.dataFolder, includingPropertiesForKeys: nil)) ?? []
        let parquets = urls
            .filter { $0.pathExtension.lowercased() == "parquet" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let iso = ISO8601DateFormatter()
        let items: [Value] = parquets.map { url in
            let name = url.lastPathComponent
            let parsed = ParquetFileNameParser.parse(name)
            return .object([
                "id": .string(name),
                "name": .string(name),
                "ticker": parsed.map { .string($0.ticker) } ?? .null,
                "start": parsed.map { .string(iso.string(from: $0.startDate)) } ?? .null,
                "end": parsed.map { .string(iso.string(from: $0.endDate)) } ?? .null,
                "timespan": parsed.map { .string($0.timespan) } ?? .null,
            ])
        }
        return .json(.object(["datasets": .array(items)]))
    }

    // MARK: - select_schema

    @MainActor
    static func selectSchema(args: [String: Value]) async throws -> CallTool.Result {
        guard let idString = args["schema_id"]?.stringValue, !idString.isEmpty else {
            throw MCPToolError.missing("schema_id")
        }
        guard let id = UUID(uuidString: idString) else {
            throw MCPToolError.invalid("schema_id", "not a UUID")
        }
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        guard doc.schemas.contains(where: { $0.id == id }) else {
            throw MCPToolError.invalid("schema_id", "no schema with id \(idString)")
        }
        handle.mutate { $0.selectedSchemaId = id }
        return .json(.object(["status": .string("ok"), "schema_id": .string(idString)]))
    }

    // MARK: - select_data

    @MainActor
    static func selectData(args: [String: Value]) async throws -> CallTool.Result {
        guard let dataId = args["data_id"]?.stringValue, !dataId.isEmpty else {
            throw MCPToolError.missing("data_id")
        }
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        let fileURL = doc.dataFolder.appendingPathComponent(dataId)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MCPToolError.invalid("data_id", "no dataset named \(dataId) in \(doc.dataFolder.path)")
        }
        handle.mutate { $0.selectedDatasetURL = fileURL }
        return .json(.object(["status": .string("ok"), "data_id": .string(dataId)]))
    }

    // MARK: - run_backtest

    @MainActor
    static func runBacktest(args _: [String: Value], server: MCP.Server? = nil) async throws -> CallTool.Result {
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        guard doc.canRunBacktest,
              let schema = doc.selectedSchema,
              let datasetURL = doc.selectedDatasetURL
        else {
            throw MCPToolError.invalid("document", "need a selected schema with a valid strategy, and a selected dataset")
        }

        let services = handle.services
        let resultFolder = doc.resultFolder
        let beforeRunFolders = listResultFolders(in: resultFolder)

        // Cancel any in-flight session so a new MCP-driven run supersedes it
        // instead of being silently ignored or racing the previous engine.
        if services.backtest.isRunning {
            await services.backtest.cancel()
            while services.backtest.isRunning {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        // Kick off the backtest. BacktestService.runBacktest spawns its own
        // background Task; we only need to `await` to set up. Completion is
        // signalled via the @Observable isRunning flag.
        await services.backtest.runBacktest(
            schema: schema,
            datasetURL: datasetURL,
            strategyFolder: doc.strategyFolder,
            resultFolder: resultFolder,
            toolbarStatusService: services.toolbar,
            strategyCacheService: services.strategyCache,
            keychainService: services.keychain
        )

        // Notify the connected client when the backtest finishes, even if
        // this tool call times out and returns early. Lets agents avoid
        // polling get_backtest_status.
        if let server {
            services.backtest.onNextCompletion { errors in
                let payload: Value = .object([
                    "event": .string("backtest_finished"),
                    "success": .bool(errors.isEmpty),
                    "errors": .array(errors.map { .string($0) }),
                ])
                Task {
                    try? await server.log(
                        level: errors.isEmpty ? .info : .error,
                        logger: "backtest",
                        data: payload
                    )
                }
            }
        }

        // Wait for completion. The backtest usually finishes within seconds for
        // small datasets; cap at 5 minutes to prevent an agent from blocking forever.
        let timeoutSeconds: Double = 5 * 60
        let started = Date()
        while services.backtest.isRunning {
            if Date().timeIntervalSince(started) > timeoutSeconds {
                throw MCPToolError.invalid("run_backtest", "timed out after \(Int(timeoutSeconds))s")
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        if !services.backtest.accumulatedErrors.isEmpty {
            let joined = services.backtest.accumulatedErrors.joined(separator: "\n")
            return .errorText("Backtest failed: \(joined)")
        }

        let afterRunFolders = listResultFolders(in: resultFolder)
        let newFolders = afterRunFolders.filter { !beforeRunFolders.contains($0) }
        let resultPath: String
        if let newest = newFolders.max(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            resultPath = newest.path
        } else {
            resultPath = resultFolder.path
        }
        return .json(.object([
            "status": .string("ok"),
            "result_path": .string(resultPath),
        ]))
    }

    // MARK: - get_backtest_status

    @MainActor
    static func getBacktestStatus(args _: [String: Value]) async throws -> CallTool.Result {
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let backtest = handle.services.backtest
        let progress: Value = .object([
            "current": .int(backtest.currentProgress.current),
            "total": .int(backtest.currentProgress.total),
        ])
        let currentStrategy: Value = backtest.currentStrategy.isEmpty
            ? .null : .string(backtest.currentStrategy)
        let currentStrategyId: Value = backtest.currentStrategyId.map { .string($0) } ?? .null
        let currentDataFile: Value = backtest.currentDataFile.isEmpty
            ? .null : .string(backtest.currentDataFile)
        let errors: [Value] = backtest.accumulatedErrors.map { .string($0) }
        return .json(.object([
            "is_running": .bool(backtest.isRunning),
            "current_strategy": currentStrategy,
            "current_strategy_id": currentStrategyId,
            "current_data_file": currentDataFile,
            "progress": progress,
            "bars_per_second": .double(backtest.currentBarsPerSecond),
            "realized_pnl": .double(backtest.currentRealizedPnL),
            "total_strategies": .int(backtest.totalStrategies),
            "total_configs": .int(backtest.totalConfigs),
            "total_data_files": .int(backtest.totalDataFiles),
            "total_data_points": .int(backtest.totalDataPoints),
            "errors": .array(errors),
        ]))
    }

    // MARK: - list_strategies

    @MainActor
    static func listStrategies(args _: [String: Value]) async throws -> CallTool.Result {
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: doc.strategyFolder, includingPropertiesForKeys: nil)) ?? []
        let wasms = urls
            .filter { $0.pathExtension.lowercased() == "wasm" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var entries: [Value] = []
        for url in wasms {
            let fileName = url.lastPathComponent
            if let metadata = try? await handle.services.strategyCache.getMetadata(for: url) {
                entries.append(.object([
                    "id": .string(metadata.identifier),
                    "name": .string(metadata.name),
                    "file": .string(fileName),
                ]))
            } else {
                entries.append(.object([
                    "id": .null,
                    "name": .null,
                    "file": .string(fileName),
                ]))
            }
        }
        return .json(.object(["strategies": .array(entries)]))
    }

    // MARK: - list_strategy_results

    @MainActor
    static func listStrategyResults(args: [String: Value]) async throws -> CallTool.Result {
        guard let strategyId = args["strategy_id"]?.stringValue, !strategyId.isEmpty else {
            throw MCPToolError.missing("strategy_id")
        }
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let items = handle.services.backtestResult.results(forStrategyId: strategyId)
        let limit = args["limit"]?.intValue
        let sliced: [BacktestResultItem] = {
            guard let limit, limit >= 0 else { return items }
            return Array(items.prefix(limit))
        }()

        let iso = ISO8601DateFormatter()
        let entries: [Value] = sliced.map { item in
            let r = item.result
            let tr = r.tradeResult
            let pnl = r.tradePnl
            var entry: [String: Value] = [
                "id": .string(r.id.uuidString),
                "symbol": .string(r.symbol),
                "run_time": .string(iso.string(from: item.runTimestamp)),
                "win_rate": .double(tr.winRate),
                "number_of_trades": .int(tr.numberOfTrades),
                "winning_trades": .int(tr.numberOfWinningTrades),
                "losing_trades": .int(tr.numberOfLosingTrades),
                "max_drawdown": .double(tr.maxDrawdown),
                "total_pnl": .double(pnl.totalPnl),
                "realized_pnl": .double(pnl.realizedPnl),
                "unrealized_pnl": .double(pnl.unrealizedPnl),
                "maximum_profit": .double(pnl.maximumProfit),
                "maximum_loss": .double(pnl.maximumLoss),
                "total_fees": .double(r.totalFees),
                "buy_and_hold_pnl": .double(r.buyAndHoldPnl),
            ]
            if let pairs = tr.numberOfTradingPairs { entry["trading_pairs"] = .int(pairs) }
            if let sharpe = tr.sharpeRatio { entry["sharpe_ratio"] = .double(sharpe) }
            if let median = pnl.medianPnl { entry["median_pnl"] = .double(median) }
            if let investment = pnl.totalInvestment { entry["total_investment"] = .double(investment) }
            if let pct = pnl.pnlPercentage { entry["pnl_percentage"] = .double(pct) }
            if let initial = r.initialBalance { entry["initial_balance"] = .double(initial) }
            if let final = r.finalBalance { entry["final_balance"] = .double(final) }
            return .object(entry)
        }
        return .json(.object([
            "strategy_id": .string(strategyId),
            "results": .array(entries),
            "total": .int(items.count),
        ]))
    }

    // MARK: - get_config

    @MainActor
    static func getConfig(args _: [String: Value]) async throws -> CallTool.Result {
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        let schemaValue: Value = doc.selectedSchema.map { schema in
            .object([
                "id": .string(schema.id.uuidString),
                "name": .string(schema.name),
                "strategy_path": .string(schema.strategyPath),
            ])
        } ?? .null
        let dataValue: Value = doc.selectedDatasetURL.map { url in
            .object([
                "id": .string(url.lastPathComponent),
                "path": .string(url.path),
            ])
        } ?? .null
        return .json(.object([
            "selected_schema": schemaValue,
            "selected_dataset": dataValue,
        ]))
    }

    // MARK: - helpers

    @MainActor
    private static func requireSchema(args: [String: Value]) throws -> Schema {
        guard let idString = args["schema_id"]?.stringValue, !idString.isEmpty else {
            throw MCPToolError.missing("schema_id")
        }
        guard let id = UUID(uuidString: idString) else {
            throw MCPToolError.invalid("schema_id", "not a UUID")
        }
        guard let handle = DocumentRegistry.shared.current() else {
            throw MCPToolError.noDocument
        }
        let doc = handle.snapshot()
        guard let schema = doc.schemas.first(where: { $0.id == id }) else {
            throw MCPToolError.invalid("schema_id", "no schema with id \(idString)")
        }
        return schema
    }

    private static func decodeJSONOrNull(_ data: Data) -> Value {
        guard !data.isEmpty else { return .null }
        return (try? JSONDecoder().decode(Value.self, from: data)) ?? .null
    }

    private static func encodeJSON(_ value: Value, field: String) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try encoder.encode(value)
        } catch {
            throw MCPToolError.invalid(field, "could not encode: \(error.localizedDescription)")
        }
    }

    private static func listResultFolders(in folder: URL) -> Set<URL> {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        return Set(urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true })
    }
}
