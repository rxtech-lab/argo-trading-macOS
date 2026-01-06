//
//  Log.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/5/26.
//

import Foundation
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
