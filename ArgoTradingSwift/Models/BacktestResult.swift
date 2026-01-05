//
//  BacktestResult.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation

struct StrategyInfo: Codable, Identifiable, Hashable {
    let id: String
    let version: String
    let name: String
}

struct BacktestResult: Codable, Identifiable, Hashable {
    let id: UUID
    let symbol: String
    let tradeResult: TradeResult
    let totalFees: Double
    let tradeHoldingTime: TradeHoldingTime
    let tradePnl: TradePnl
    let strategy: StrategyInfo
    let strategyPath: String
    let buyAndHoldPnl: Double
    let tradesFilePath: String
    let ordersFilePath: String
    let marksFilePath: String
    let dataFilePath: String

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case tradeResult = "trade_result"
        case totalFees = "total_fees"
        case tradeHoldingTime = "trade_holding_time"
        case tradePnl = "trade_pnl"
        case buyAndHoldPnl = "buy_and_hold_pnl"
        case tradesFilePath = "trades_file_path"
        case ordersFilePath = "orders_file_path"
        case marksFilePath = "marks_file_path"
        case dataFilePath = "data_path"
        case strategyPath = "strategy_path"
        case strategy
    }
}

struct TradeResult: Codable, Hashable {
    let numberOfTrades: Int
    let numberOfWinningTrades: Int
    let numberOfLosingTrades: Int
    let winRate: Double
    let maxDrawdown: Double

    enum CodingKeys: String, CodingKey {
        case numberOfTrades = "number_of_trades"
        case numberOfWinningTrades = "number_of_winning_trades"
        case numberOfLosingTrades = "number_of_losing_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
    }
}

struct TradeHoldingTime: Codable, Hashable {
    let min: Double
    let max: Double
    let avg: Double
}

struct TradePnl: Codable, Hashable {
    let realizedPnl: Double
    let unrealizedPnl: Double
    let totalPnl: Double
    let maximumLoss: Double
    let maximumProfit: Double

    enum CodingKeys: String, CodingKey {
        case realizedPnl = "realized_pnl"
        case unrealizedPnl = "unrealized_pnl"
        case totalPnl = "total_pnl"
        case maximumLoss = "maximum_loss"
        case maximumProfit = "maximum_profit"
    }
}

/// Wrapper with metadata extracted from folder path
struct BacktestResultItem: Identifiable, Hashable {
    let result: BacktestResult
    let statsFileURL: URL
    let runTimestamp: Date
    let parsedFileName: ParsedParquetFileName?

    var id: UUID { result.id }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var displayTime: String {
        Self.timeFormatter.string(from: runTimestamp)
    }
}
