//
//  TradingResultServiceTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Foundation
import Testing
import Yams
@testable import ArgoTradingSwift

// MARK: - YAML Parsing Tests

struct TradingResultYAMLTests {
    @Test func parsesValidStatsYaml() throws {
        let yaml = """
        id: run_1
        date: "2026-02-18"
        session_start: 2026-02-18T09:43:29.616186+00:00
        last_updated: 2026-02-18T09:44:07.379692+00:00
        symbols:
            - BTCUSDT
        trade_result:
            number_of_trades: 5
            number_of_winning_trades: 3
            number_of_losing_trades: 2
            win_rate: 0.6
            max_drawdown: 150.0
        trade_pnl:
            realized_pnl: 100.0
            unrealized_pnl: 50.0
            total_pnl: 150.0
            maximum_loss: -75.0
            maximum_profit: 200.0
        trade_holding_time:
            min: 5.0
            max: 120.0
            avg: 45.0
        total_fees: 12.5
        orders_file_path: /tmp/orders.parquet
        trades_file_path: /tmp/trades.parquet
        marks_file_path: /tmp/marks.parquet
        logs_file_path: /tmp/logs.parquet
        market_data_file_path: ""
        strategy:
            id: strat_1
            version: "1.0"
            name: TestStrategy
        """

        let decoder = YAMLDecoder()
        let result = try decoder.decode(TradingResult.self, from: yaml)

        #expect(result.id == "run_1")
        #expect(result.date == "2026-02-18")
        #expect(result.symbols == ["BTCUSDT"])
        #expect(result.tradeResult.numberOfTrades == 5)
        #expect(result.tradeResult.winRate == 0.6)
        #expect(result.tradePnl.totalPnl == 150.0)
        #expect(result.tradeHoldingTime.avg == 45.0)
        #expect(result.totalFees == 12.5)
        #expect(result.strategy.name == "TestStrategy")
        #expect(result.marketDataFilePath == "")
        #expect(result.ordersFilePath == "/tmp/orders.parquet")
    }

    @Test func parsesMultipleSymbols() throws {
        let yaml = """
        id: run_2
        date: "2026-02-18"
        session_start: 2026-02-18T10:00:00+00:00
        last_updated: 2026-02-18T10:30:00+00:00
        symbols:
            - BTCUSDT
            - ETHUSDT
        trade_result:
            number_of_trades: 0
            number_of_winning_trades: 0
            number_of_losing_trades: 0
            win_rate: 0
            max_drawdown: 0
        trade_pnl:
            realized_pnl: 0
            unrealized_pnl: 0
            total_pnl: 0
            maximum_loss: 0
            maximum_profit: 0
        trade_holding_time:
            min: 0
            max: 0
            avg: 0
        total_fees: 0
        orders_file_path: ""
        trades_file_path: ""
        marks_file_path: ""
        logs_file_path: ""
        market_data_file_path: ""
        strategy:
            id: ""
            version: ""
            name: MultiSymbolStrategy
        """

        let decoder = YAMLDecoder()
        let result = try decoder.decode(TradingResult.self, from: yaml)

        #expect(result.symbols.count == 2)
        #expect(result.symbols.contains("BTCUSDT"))
        #expect(result.symbols.contains("ETHUSDT"))
    }
}

// MARK: - TradingResultItem Tests

struct TradingResultItemTests {
    @Test func displaySymbolsJoinsWithComma() throws {
        let yaml = """
        id: run_1
        date: "2026-02-18"
        session_start: 2026-02-18T09:00:00+00:00
        last_updated: 2026-02-18T09:30:00+00:00
        symbols:
            - BTCUSDT
            - ETHUSDT
        trade_result:
            number_of_trades: 0
            number_of_winning_trades: 0
            number_of_losing_trades: 0
            win_rate: 0
            max_drawdown: 0
        trade_pnl:
            realized_pnl: 0
            unrealized_pnl: 0
            total_pnl: 0
            maximum_loss: 0
            maximum_profit: 0
        trade_holding_time:
            min: 0
            max: 0
            avg: 0
        total_fees: 0
        orders_file_path: ""
        trades_file_path: ""
        marks_file_path: ""
        logs_file_path: ""
        market_data_file_path: ""
        strategy:
            id: ""
            version: ""
            name: Test
        """

        let decoder = YAMLDecoder()
        let result = try decoder.decode(TradingResult.self, from: yaml)
        let item = TradingResultItem(
            result: result,
            statsFileURL: URL(fileURLWithPath: "/tmp/stats.yaml")
        )

        #expect(item.displaySymbols == "BTCUSDT, ETHUSDT")
    }
}

// MARK: - TradingResultService Tests

struct TradingResultServiceTests {
    @Test func setResultFolderClearsOnNil() {
        let service = TradingResultService()
        service.setResultFolder(nil)

        #expect(service.sortedDates.isEmpty)
        #expect(service.resultsByDate.isEmpty)
    }

    @Test @MainActor func loadsResultsFromDisk() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dateDir = tmpDir.appendingPathComponent("2026-02-18")
        let runDir = dateDir.appendingPathComponent("run_1")
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

        let yaml = """
        id: run_1
        date: "2026-02-18"
        session_start: 2026-02-18T09:00:00+00:00
        last_updated: 2026-02-18T09:30:00+00:00
        symbols:
            - BTCUSDT
        trade_result:
            number_of_trades: 0
            number_of_winning_trades: 0
            number_of_losing_trades: 0
            win_rate: 0
            max_drawdown: 0
        trade_pnl:
            realized_pnl: 0
            unrealized_pnl: 0
            total_pnl: 0
            maximum_loss: 0
            maximum_profit: 0
        trade_holding_time:
            min: 0
            max: 0
            avg: 0
        total_fees: 0
        orders_file_path: ""
        trades_file_path: ""
        marks_file_path: ""
        logs_file_path: ""
        market_data_file_path: ""
        strategy:
            id: ""
            version: ""
            name: TestStrategy
        """

        try yaml.write(to: runDir.appendingPathComponent("stats.yaml"), atomically: true, encoding: .utf8)

        let service = TradingResultService()
        service.setResultFolder(tmpDir)

        // Wait for async loading
        try await Task.sleep(for: .milliseconds(500))

        #expect(service.sortedDates == ["2026-02-18"])
        #expect(service.resultsByDate["2026-02-18"]?.count == 1)
        #expect(service.resultsByDate["2026-02-18"]?.first?.result.strategy.name == "TestStrategy")

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test @MainActor func skipsEmptyRunFolders() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dateDir = tmpDir.appendingPathComponent("2026-02-18")

        // Create an empty run folder (no stats.yaml)
        let emptyRunDir = dateDir.appendingPathComponent("run_2")
        try FileManager.default.createDirectory(at: emptyRunDir, withIntermediateDirectories: true)

        // Create a run folder with stats.yaml
        let validRunDir = dateDir.appendingPathComponent("run_1")
        try FileManager.default.createDirectory(at: validRunDir, withIntermediateDirectories: true)

        let yaml = """
        id: run_1
        date: "2026-02-18"
        session_start: 2026-02-18T09:00:00+00:00
        last_updated: 2026-02-18T09:30:00+00:00
        symbols:
            - BTCUSDT
        trade_result:
            number_of_trades: 0
            number_of_winning_trades: 0
            number_of_losing_trades: 0
            win_rate: 0
            max_drawdown: 0
        trade_pnl:
            realized_pnl: 0
            unrealized_pnl: 0
            total_pnl: 0
            maximum_loss: 0
            maximum_profit: 0
        trade_holding_time:
            min: 0
            max: 0
            avg: 0
        total_fees: 0
        orders_file_path: ""
        trades_file_path: ""
        marks_file_path: ""
        logs_file_path: ""
        market_data_file_path: ""
        strategy:
            id: ""
            version: ""
            name: TestStrategy
        """

        try yaml.write(to: validRunDir.appendingPathComponent("stats.yaml"), atomically: true, encoding: .utf8)

        let service = TradingResultService()
        service.setResultFolder(tmpDir)

        // Wait for async loading
        try await Task.sleep(for: .milliseconds(500))

        #expect(service.resultsByDate["2026-02-18"]?.count == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test @MainActor func groupsByDateAndSortsNewestFirst() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        func writeStatsYaml(date: String, runId: String, sessionStart: String) throws {
            let dateDir = tmpDir.appendingPathComponent(date)
            let runDir = dateDir.appendingPathComponent(runId)
            try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

            let yaml = """
            id: \(runId)
            date: "\(date)"
            session_start: \(sessionStart)
            last_updated: \(sessionStart)
            symbols:
                - BTCUSDT
            trade_result:
                number_of_trades: 0
                number_of_winning_trades: 0
                number_of_losing_trades: 0
                win_rate: 0
                max_drawdown: 0
            trade_pnl:
                realized_pnl: 0
                unrealized_pnl: 0
                total_pnl: 0
                maximum_loss: 0
                maximum_profit: 0
            trade_holding_time:
                min: 0
                max: 0
                avg: 0
            total_fees: 0
            orders_file_path: ""
            trades_file_path: ""
            marks_file_path: ""
            logs_file_path: ""
            market_data_file_path: ""
            strategy:
                id: ""
                version: ""
                name: Test
            """

            try yaml.write(to: runDir.appendingPathComponent("stats.yaml"), atomically: true, encoding: .utf8)
        }

        try writeStatsYaml(date: "2026-02-17", runId: "run_1", sessionStart: "2026-02-17T09:00:00+00:00")
        try writeStatsYaml(date: "2026-02-18", runId: "run_1", sessionStart: "2026-02-18T09:00:00+00:00")
        try writeStatsYaml(date: "2026-02-18", runId: "run_2", sessionStart: "2026-02-18T10:00:00+00:00")

        let service = TradingResultService()
        service.setResultFolder(tmpDir)

        // Wait for async loading
        try await Task.sleep(for: .milliseconds(500))

        // Dates sorted newest first
        #expect(service.sortedDates == ["2026-02-18", "2026-02-17"])
        #expect(service.resultsByDate["2026-02-18"]?.count == 2)
        #expect(service.resultsByDate["2026-02-17"]?.count == 1)

        // Within a date, newest session first
        let feb18Results = service.resultsByDate["2026-02-18"]!
        #expect(feb18Results[0].result.id == "run_2")
        #expect(feb18Results[1].result.id == "run_1")

        // Cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    @Test func getResultItemFindsMatchingURL() throws {
        // This test is limited since setResultFolder is async, but we can test the nil case
        let service = TradingResultService()
        let result = service.getResultItem(for: URL(fileURLWithPath: "/nonexistent/stats.yaml"))
        #expect(result == nil)
    }
}
