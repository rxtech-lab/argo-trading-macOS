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
    case oneHour = "1h"
    case oneDay = "1d"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// DuckDB date_trunc interval string
    var duckDBInterval: String {
        switch self {
        case .oneSecond: return "second"
        case .oneMinute: return "minute"
        case .oneHour: return "hour"
        case .oneDay: return "day"
        }
    }

    /// Number of seconds in this interval
    var seconds: Int {
        switch self {
        case .oneSecond: return 1
        case .oneMinute: return 60
        case .oneHour: return 3600
        case .oneDay: return 86400
        }
    }
}
