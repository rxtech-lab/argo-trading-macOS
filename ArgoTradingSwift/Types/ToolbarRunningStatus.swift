//
//  ToolbarRunningStatus.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/22/25.
//
import Foundation

struct Progress: Equatable {
    let current: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0.0 }
        return (Double(current) / Double(total)) * 100.0
    }
}

enum ToolbarRunningStatus: Equatable {
    case running(label: String)
    case downloading(label: String, progress: Progress)
    case downloadCancelled(label: String)
    case backtesting(label: String, progress: Progress)
    case trading(label: String)
    case idle
    case error(label: String, errors: [String], at: Date)
    case finished(message: String, at: Date)

    var animationId: String {
        switch self {
        case .idle: return "idle"
        case .downloadCancelled(let label): return "downloadCancelled-\(label)"
        case .downloading(let label, _): return "downloading-\(label)"
        case .running(let label): return "running-\(label)"
        case .backtesting: return "backtesting"
        case .trading(let label): return "trading-\(label)"
        case .error: return "error"
        case .finished: return "finished"
        }
    }
}
