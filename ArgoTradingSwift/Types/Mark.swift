//
//  Mark.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation

struct Mark: Codable, Hashable, Identifiable {
    let marketDataId: String
    let color: String
    let shape: MarkShape
    let title: String
    let message: String
    let category: String
    let signal: Signal?

    var id: String { marketDataId }

    enum CodingKeys: String, CodingKey {
        case marketDataId = "market_data_id"
        case color
        case shape
        case title
        case message
        case category
        case signal
    }
}

enum MarkShape: String, Codable {
    case circle
    case square
    case triangle
}

struct Signal: Codable, Hashable {
    let time: Date
    let type: SignalType
    let name: String
    let reason: String
    let rawValue: String?
    let symbol: String
    let indicator: String

    enum CodingKeys: String, CodingKey {
        case time
        case type
        case name
        case reason
        case rawValue = "raw_value"
        case symbol
        case indicator
    }
}

enum SignalType: String, Codable {
    case buyLong = "buy_long"
    case sellLong = "sell_long"
    case buyShort = "buy_short"
    case sellShort = "sell_short"
    case noAction = "no_action"
    case closePosition = "close_position"
    case wait
    case abort

    var isBuy: Bool {
        self == .buyLong || self == .buyShort
    }

    var isSell: Bool {
        self == .sellLong || self == .sellShort
    }
}
