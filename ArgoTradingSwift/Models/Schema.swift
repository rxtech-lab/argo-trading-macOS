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

struct Schema: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var parameters: Data
    var strategyPath: String
    var runningStatus: SchemaRunningStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        parameters: Data = Data(),
        strategyPath: String = "",
        runningStatus: SchemaRunningStatus = .idle,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.strategyPath = strategyPath
        self.runningStatus = runningStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
