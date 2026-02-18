//
//  TradingResult.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

struct TradingResult: Decodable, Identifiable, Hashable {
    let id: String
    let date: String
    let name: String
    let sessionStart: Date
    let lastUpdated: Date
    let symbols: [String]
    let tradeResult: TradeResult
    let tradePnl: TradePnl
    let tradeHoldingTime: TradeHoldingTime
    let totalFees: Double
    let ordersFilePath: String
    let tradesFilePath: String
    let marksFilePath: String
    let logsFilePath: String
    let marketDataFilePath: String
    let strategy: StrategyInfo

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case name
        case sessionStart = "session_start"
        case lastUpdated = "last_updated"
        case symbols
        case tradeResult = "trade_result"
        case tradePnl = "trade_pnl"
        case tradeHoldingTime = "trade_holding_time"
        case totalFees = "total_fees"
        case ordersFilePath = "orders_file_path"
        case tradesFilePath = "trades_file_path"
        case marksFilePath = "marks_file_path"
        case logsFilePath = "logs_file_path"
        case marketDataFilePath = "market_data_file_path"
        case strategy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        sessionStart = try container.decode(Date.self, forKey: .sessionStart)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        symbols = try container.decode([String].self, forKey: .symbols)
        tradeResult = try container.decode(TradeResult.self, forKey: .tradeResult)
        tradePnl = try container.decode(TradePnl.self, forKey: .tradePnl)
        tradeHoldingTime = try container.decode(TradeHoldingTime.self, forKey: .tradeHoldingTime)
        totalFees = try container.decode(Double.self, forKey: .totalFees)
        ordersFilePath = try container.decode(String.self, forKey: .ordersFilePath)
        tradesFilePath = try container.decode(String.self, forKey: .tradesFilePath)
        marksFilePath = try container.decode(String.self, forKey: .marksFilePath)
        logsFilePath = try container.decode(String.self, forKey: .logsFilePath)
        marketDataFilePath = try container.decode(String.self, forKey: .marketDataFilePath)
        strategy = try container.decode(StrategyInfo.self, forKey: .strategy)
    }
}

/// Wrapper with metadata extracted from folder path
struct TradingResultItem: Identifiable, Hashable {
    let result: TradingResult
    let statsFileURL: URL

    var id: String { result.id + "-" + statsFileURL.path }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var displayTime: String {
        Self.timeFormatter.string(from: result.sessionStart)
    }

    var displaySymbols: String {
        result.symbols.joined(separator: ", ")
    }
}
