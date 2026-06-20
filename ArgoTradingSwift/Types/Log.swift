//
//  Log.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/5/26.
//

import Foundation
import LightweightChart
import SwiftUI

enum LogLevel: String, Codable, CaseIterable, Hashable, Comparable {
    case info
    case warning
    case error
    case debug

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        func rank(_ level: LogLevel) -> Int {
            switch level {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            }
        }
        return rank(lhs) < rank(rhs)
    }

    var foregroundColor: Color {
        switch self {
        case .debug:
            return .gray
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .debug:
            return "ladybug.fill"
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        }
    }
}

// MARK: - LightweightChart Conversion

extension Log {
    /// Convert Log to MarkerDataJS for LightweightChart display.
    func toMarkerDataJS() -> MarkerDataJS {
        var marker = MarkerDataJS(
            time: timestamp.timeIntervalSince1970,
            position: "belowBar",
            color: level.markerColor,
            shape: "circle",
            text: "",
            id: "log-\(id)",
            markerType: "log"
        )
        marker.title = level.markerTitle
        marker.category = symbol
        marker.message = message
        marker.signalReason = fields
        marker.level = level.rawValue
        return marker
    }
}

private extension LogLevel {
    var markerColor: String {
        switch self {
        case .debug: return "#8e8e93"
        case .info: return "#0a84ff"
        case .warning: return "#ff9f0a"
        case .error: return "#ff453a"
        }
    }

    var markerTitle: String {
        switch self {
        case .debug: return "Debug Log"
        case .info: return "Info Log"
        case .warning: return "Warning Log"
        case .error: return "Error Log"
        }
    }
}

struct Log: Codable, Hashable, Identifiable {
    let id: Int64
    let timestamp: Date
    let symbol: String
    let level: LogLevel
    let message: String
    let fields: String

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case symbol
        case level
        case message
        case fields
    }
}
