//
//  Mark.swift
//
//  Created by Claude on 12/27/25.
//

import Foundation
import LightweightChart
import SwiftUI

enum MarkLevel: String, Codable, CaseIterable, Hashable, Comparable {
    case info
    case warning
    case error

    static func < (lhs: MarkLevel, rhs: MarkLevel) -> Bool {
        func rank(_ level: MarkLevel) -> Int {
            switch level {
            case .info: return 0
            case .warning: return 1
            case .error: return 2
            }
        }
        return rank(lhs) < rank(rhs)
    }

    var foregroundColor: Color {
        switch self {
        case .info: return .secondary
        case .warning: return .orange
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

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
    let id: String
    let color: MarkColor
    let shape: MarkShape
    let title: String
    let message: String
    let category: String
    let signal: Signal
    let level: MarkLevel

    enum CodingKeys: String, CodingKey {
        case id
        case color
        case shape
        case title
        case message
        case category
        case signal
        case level
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

// MARK: - LightweightChart Conversion

extension Mark {
    /// Convert Mark to MarkerDataJS for LightweightChart display
    func toMarkerDataJS() -> MarkerDataJS {
        var marker = MarkerDataJS(
            time: signal.time.timeIntervalSince1970,
            position: "belowBar",
            color: color.toHexString(),
            shape: shape.toJSShape(),
            text: title,
            id: id,
            markerType: "mark"
        )
        marker.title = title
        marker.category = category
        marker.message = message
        marker.signalType = signal.type.rawValue
        marker.signalReason = signal.reason
        marker.level = level.rawValue
        return marker
    }
}
