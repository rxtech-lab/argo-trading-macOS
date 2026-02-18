//
//  Schema.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import Foundation

enum SchemaRunningStatus: String, Codable, CaseIterable {
    case idle
    case running
    case completed
    case failed

    var title: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

struct Schema: Identifiable, Hashable {
    var id: UUID
    var name: String
    var parameters: Data
    var backtestEngineConfig: Data
    var liveTradingEngineConfig: Data
    var strategyPath: String
    var runningStatus: SchemaRunningStatus
    var keychainFieldNames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parameters: Data = Data(),
        backtestEngineConfig: Data = Data(),
        liveTradingEngineConfig: Data = Data(),
        strategyPath: String = "",
        runningStatus: SchemaRunningStatus = .idle,
        keychainFieldNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.backtestEngineConfig = backtestEngineConfig
        self.liveTradingEngineConfig = liveTradingEngineConfig
        self.strategyPath = strategyPath
        self.runningStatus = runningStatus
        self.keychainFieldNames = keychainFieldNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Returns true if the schema has a non-empty strategy path
    var hasValidStrategyPath: Bool {
        !strategyPath.isEmpty
    }

    var hasKeychainFields: Bool {
        !keychainFieldNames.isEmpty
    }
}

extension Schema: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, parameters, backtestEngineConfig, liveTradingEngineConfig, strategyPath
        case runningStatus, keychainFieldNames, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        parameters = try container.decode(Data.self, forKey: .parameters)
        backtestEngineConfig = try container.decode(Data.self, forKey: .backtestEngineConfig)
        liveTradingEngineConfig = try container.decodeIfPresent(Data.self, forKey: .liveTradingEngineConfig) ?? Data()
        strategyPath = try container.decode(String.self, forKey: .strategyPath)
        runningStatus = try container.decode(SchemaRunningStatus.self, forKey: .runningStatus)
        keychainFieldNames = try container.decodeIfPresent([String].self, forKey: .keychainFieldNames) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
