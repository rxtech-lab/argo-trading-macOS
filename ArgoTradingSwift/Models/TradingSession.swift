//
//  TradingSession.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

enum TradingSessionStatus: String, Codable, CaseIterable {
    case idle
    case prefetching
    case connecting
    case running
    case stopped
    case error

    var title: String {
        switch self {
        case .idle: return "Idle"
        case .prefetching: return "Prefetching"
        case .connecting: return "Connecting"
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}

struct TradingSession: Identifiable, Hashable {
    var id: UUID
    var tradingProviderId: UUID
    var providerName: String
    var status: TradingSessionStatus
    var startedAt: Date?
    var stoppedAt: Date?
    var pnl: Double
    var tradeCount: Int
    var dataFilePath: String?
    var tradesFilePath: String?
    var marksFilePath: String?

    init(
        id: UUID = UUID(),
        tradingProviderId: UUID,
        providerName: String,
        status: TradingSessionStatus = .idle,
        startedAt: Date? = nil,
        stoppedAt: Date? = nil,
        pnl: Double = 0,
        tradeCount: Int = 0,
        dataFilePath: String? = nil,
        tradesFilePath: String? = nil,
        marksFilePath: String? = nil
    ) {
        self.id = id
        self.tradingProviderId = tradingProviderId
        self.providerName = providerName
        self.status = status
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.pnl = pnl
        self.tradeCount = tradeCount
        self.dataFilePath = dataFilePath
        self.tradesFilePath = tradesFilePath
        self.marksFilePath = marksFilePath
    }
}
