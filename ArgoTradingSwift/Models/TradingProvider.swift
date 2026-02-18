//
//  TradingProvider.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

struct TradingProvider: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var marketDataProvider: String
    var tradingSystemProvider: String
    var tradingSystemConfig: Data
    var liveTradingEngineConfig: Data
    var keychainFieldNames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        marketDataProvider: String = "",
        tradingSystemProvider: String = "",
        tradingSystemConfig: Data = Data(),
        liveTradingEngineConfig: Data = Data(),
        keychainFieldNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.marketDataProvider = marketDataProvider
        self.tradingSystemProvider = tradingSystemProvider
        self.tradingSystemConfig = tradingSystemConfig
        self.liveTradingEngineConfig = liveTradingEngineConfig
        self.keychainFieldNames = keychainFieldNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasKeychainFields: Bool {
        !keychainFieldNames.isEmpty
    }
}
