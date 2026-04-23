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

enum PortfolioCalculation: String, Codable, Hashable {
    case averageCost = "average_cost"
    case fifo
    case lifo

    var displayName: String {
        switch self {
        case .averageCost: return "Average Cost"
        case .fifo: return "FIFO"
        case .lifo: return "LIFO"
        }
    }
}

struct BacktestResult: Codable, Identifiable, Hashable {
    let id: UUID
    let portfolioCalculation: PortfolioCalculation?
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
    let logFilePath: String
    let initialBalance: Double?
    let finalBalance: Double?
    let monthlyTrades: [MonthlyTrade]?
    let monthlyBalance: [MonthlyBalance]?
    let monthlyHoldingTime: [MonthlyHoldingTime]?
    let backtestConfig: [String: YAMLValue]?
    let strategyConfig: [String: YAMLValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case portfolioCalculation = "portfolio_calculation"
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
        case logFilePath = "logs_file_path"
        case strategyPath = "strategy_path"
        case strategy
        case initialBalance = "initial_balance"
        case finalBalance = "final_balance"
        case monthlyTrades = "monthly_trades"
        case monthlyBalance = "monthly_balance"
        case monthlyHoldingTime = "monthly_holding_time"
        case backtestConfig = "backtest_config"
        case strategyConfig = "strategy_config"
    }
}

struct TradeResult: Codable, Hashable {
    let numberOfTrades: Int
    let numberOfTradingPairs: Int?
    let numberOfWinningTrades: Int
    let numberOfLosingTrades: Int
    let winRate: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?

    enum CodingKeys: String, CodingKey {
        case numberOfTrades = "number_of_trades"
        case numberOfTradingPairs = "number_of_trading_pairs"
        case numberOfWinningTrades = "number_of_winning_trades"
        case numberOfLosingTrades = "number_of_losing_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
    }
}

struct TradeHoldingTime: Codable, Hashable {
    let min: Double
    let max: Double
    let avg: Double
    let median: Double?
    let percentiles: Percentiles?
}

struct TradePnl: Codable, Hashable {
    let realizedPnl: Double
    let unrealizedPnl: Double
    let totalPnl: Double
    let maximumLoss: Double
    let maximumProfit: Double
    let medianPnl: Double?
    let percentiles: Percentiles?
    let totalInvestment: Double?
    let pnlPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case realizedPnl = "realized_pnl"
        case unrealizedPnl = "unrealized_pnl"
        case totalPnl = "total_pnl"
        case maximumLoss = "maximum_loss"
        case maximumProfit = "maximum_profit"
        case medianPnl = "median_pnl"
        case percentiles
        case totalInvestment = "total_investment"
        case pnlPercentage = "pnl_percentage"
    }
}

struct Percentiles: Codable, Hashable {
    let p25: Double
    let p50: Double
    let p75: Double
    let p90: Double
    let p95: Double
    let p99: Double
}

struct MonthlyTrade: Codable, Hashable, Identifiable {
    let month: String
    let numberOfTrades: Int
    let numberOfTradingPairs: Int
    let numberOfWinningTrades: Int
    let numberOfLosingTrades: Int

    var id: String { month }

    enum CodingKeys: String, CodingKey {
        case month
        case numberOfTrades = "number_of_trades"
        case numberOfTradingPairs = "number_of_trading_pairs"
        case numberOfWinningTrades = "number_of_winning_trades"
        case numberOfLosingTrades = "number_of_losing_trades"
    }
}

struct MonthlyBalance: Codable, Hashable, Identifiable {
    let month: String
    let startingBalance: Double
    let endingBalance: Double
    let change: Double
    let realizedPnl: Double

    var id: String { month }

    enum CodingKeys: String, CodingKey {
        case month
        case startingBalance = "starting_balance"
        case endingBalance = "ending_balance"
        case change
        case realizedPnl = "realized_pnl"
    }
}

struct MonthlyHoldingTime: Codable, Hashable, Identifiable {
    let month: String
    let min: Double
    let max: Double
    let avg: Double
    let median: Double?

    var id: String { month }
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

    var displayDateTime: String {
        runTimestamp.formatted(date: .abbreviated, time: .shortened)
    }
}
