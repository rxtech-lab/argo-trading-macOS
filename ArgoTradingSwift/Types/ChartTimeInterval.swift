//
//  ChartTimeInterval.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation

/// Time intervals for aggregating price chart data
enum ChartTimeInterval: String, CaseIterable, Identifiable {
    case oneSecond = "1s"
    case oneMinute = "1m"
    case threeMinutes = "3m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case twoHours = "2h"
    case fourHours = "4h"
    case sixHours = "6h"
    case eightHours = "8h"
    case twelveHours = "12h"
    case oneDay = "1d"
    case threeDays = "3d"
    case oneWeek = "1w"
    case oneMonth = "1M"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// DuckDB date_trunc interval string (base unit for aggregation)
    var duckDBInterval: String {
        switch self {
        case .oneSecond: return "second"
        case .oneMinute, .threeMinutes, .fiveMinutes, .fifteenMinutes, .thirtyMinutes:
            return "minute"
        case .oneHour, .twoHours, .fourHours, .sixHours, .eightHours, .twelveHours:
            return "hour"
        case .oneDay, .threeDays: return "day"
        case .oneWeek: return "week"
        case .oneMonth: return "month"
        }
    }

    /// Number of seconds in this interval
    var seconds: Int {
        switch self {
        case .oneSecond: return 1
        case .oneMinute: return 60
        case .threeMinutes: return 180
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .thirtyMinutes: return 1800
        case .oneHour: return 3600
        case .twoHours: return 7200
        case .fourHours: return 14400
        case .sixHours: return 21600
        case .eightHours: return 28800
        case .twelveHours: return 43200
        case .oneDay: return 86400
        case .threeDays: return 259200
        case .oneWeek: return 604800
        case .oneMonth: return 2592000  // ~30 days
        }
    }

    /// Multiplier for sub-interval aggregation (for intervals like 3m, 5m, etc.)
    /// Returns nil if the interval maps directly to a DuckDB date_trunc unit
    var aggregationMultiplier: Int? {
        switch self {
        case .threeMinutes: return 3
        case .fiveMinutes: return 5
        case .fifteenMinutes: return 15
        case .thirtyMinutes: return 30
        case .twoHours: return 2
        case .fourHours: return 4
        case .sixHours: return 6
        case .eightHours: return 8
        case .twelveHours: return 12
        case .threeDays: return 3
        default: return nil
        }
    }
}

// MARK: - Filtering

extension ChartTimeInterval {
    /// Filter intervals to only those >= the given minimum seconds
    static func filtered(minimumSeconds: Int) -> [ChartTimeInterval] {
        allCases.filter { $0.seconds >= minimumSeconds }
    }

    /// Filter intervals based on a parsed filename
    static func filtered(for url: URL) -> [ChartTimeInterval] {
        let fileName = url.lastPathComponent
        guard let parsed = ParquetFileNameParser.parse(fileName),
              let minSeconds = parsed.timespanSeconds else {
            return Array(allCases)
        }
        return filtered(minimumSeconds: minSeconds)
    }
}
