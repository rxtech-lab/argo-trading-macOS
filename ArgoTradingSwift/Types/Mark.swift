//
//  Mark.swift
//
//  Created by Claude on 12/27/25.
//

import Foundation
import SwiftUI

enum MarkColor: Codable, Equatable, Hashable, Comparable {
    case red
    case green
    case blue
    case yellow
    case purple
    case orange
    case fromRawValue(hexString: String)

    init(string: String) {
        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "red":
            self = .red
        case "green":
            self = .green
        case "blue":
            self = .blue
        case "yellow":
            self = .yellow
        case "purple":
            self = .purple
        case "orange":
            self = .orange
        default:
            self = .fromRawValue(hexString: string)
        }
    }
}

struct Mark: Codable, Hashable, Identifiable {
    let marketDataId: String
    let color: MarkColor
    let shape: MarkShape
    let title: String
    let message: String
    let category: String
    let signal: Signal

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

extension MarkColor {
    /// Convert `MarkColor` to a SwiftUI `Color`.
    /// - Returns: A `Color` representing the enum case. For `.fromRawValue`, attempts to parse a hex string like `#RRGGBB`, `#RRGGBBAA`, `RRGGBB`, or `RRGGBBAA`.
    func toColor() -> Color {
        switch self {
        case .red:
            return .red
        case .green:
            return .green
        case .blue:
            return .blue
        case .yellow:
            return .yellow
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .fromRawValue(let hexString):
            if let color = Color(hex: hexString) {
                return color
            } else {
                // Fallback if parsing fails
                return .gray
            }
        }
    }

    func rawValue() -> String {
        toColor().description
    }
}
