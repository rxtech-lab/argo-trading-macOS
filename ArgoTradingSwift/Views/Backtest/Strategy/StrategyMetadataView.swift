//
//  StrategyMetadataView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import ArgoTrading
import SwiftUI

struct StrategyMetadataView: View {
    let strategyMetadata: SwiftargoStrategyMetadata
    let strategyId: String?

    @Environment(BacktestResultService.self) private var backtestResultService

    // MARK: - Computed Properties

    private var results: [BacktestResultItem] {
        guard let strategyId else { return [] }
        return backtestResultService.results(forStrategyId: strategyId)
    }

    // MARK: - Overview Statistics

    private var totalTrades: Int {
        results.reduce(0) { $0 + $1.result.tradeResult.numberOfTrades }
    }

    private var winningTrades: Int {
        results.reduce(0) { $0 + $1.result.tradeResult.numberOfWinningTrades }
    }

    private var losingTrades: Int {
        results.reduce(0) { $0 + $1.result.tradeResult.numberOfLosingTrades }
    }

    // MARK: - Win Rate Statistics

    private var bestWinRate: Double {
        results.map { $0.result.tradeResult.winRate }.max() ?? 0
    }

    private var avgWinRate: Double {
        guard !results.isEmpty else { return 0 }
        let sum = results.reduce(0.0) { $0 + $1.result.tradeResult.winRate }
        return sum / Double(results.count)
    }

    private var profitFactor: Double {
        let totalProfit = results.reduce(0.0) { sum, item in
            sum + max(0, item.result.tradePnl.totalPnl)
        }
        let totalLoss = results.reduce(0.0) { sum, item in
            sum + abs(min(0, item.result.tradePnl.totalPnl))
        }
        guard totalLoss > 0 else { return totalProfit > 0 ? Double.infinity : 0 }
        return totalProfit / totalLoss
    }

    // MARK: - PnL Statistics

    private var bestPnl: Double {
        results.map { $0.result.tradePnl.totalPnl }.max() ?? 0
    }

    private var worstPnl: Double {
        results.map { $0.result.tradePnl.totalPnl }.min() ?? 0
    }

    private var totalPnl: Double {
        results.reduce(0.0) { $0 + $1.result.tradePnl.totalPnl }
    }

    private var avgPnl: Double {
        guard !results.isEmpty else { return 0 }
        return totalPnl / Double(results.count)
    }

    private var bestSingleTrade: Double {
        results.map { $0.result.tradePnl.maximumProfit }.max() ?? 0
    }

    private var worstSingleTrade: Double {
        results.map { $0.result.tradePnl.maximumLoss }.min() ?? 0
    }

    // MARK: - Symbol Performance

    private var symbolPnlMap: [String: Double] {
        var map: [String: Double] = [:]
        for item in results {
            let symbol = item.result.symbol
            map[symbol, default: 0] += item.result.tradePnl.totalPnl
        }
        return map
    }

    private var bestSymbol: String {
        symbolPnlMap.max(by: { $0.value < $1.value })?.key ?? "-"
    }

    private var worstSymbol: String {
        symbolPnlMap.min(by: { $0.value < $1.value })?.key ?? "-"
    }

    // MARK: - Holding Time Statistics

    private var avgHoldingTime: Double {
        guard !results.isEmpty else { return 0 }
        let sum = results.reduce(0.0) { $0 + $1.result.tradeHoldingTime.avg }
        return sum / Double(results.count)
    }

    private var minHoldingTime: Double {
        results.map { $0.result.tradeHoldingTime.min }.min() ?? 0
    }

    private var maxHoldingTime: Double {
        results.map { $0.result.tradeHoldingTime.max }.max() ?? 0
    }

    // MARK: - Risk Statistics

    private var avgDrawdown: Double {
        guard !results.isEmpty else { return 0 }
        let sum = results.reduce(0.0) { $0 + $1.result.tradeResult.maxDrawdown }
        return sum / Double(results.count)
    }

    private var worstDrawdown: Double {
        results.map { $0.result.tradeResult.maxDrawdown }.max() ?? 0
    }

    private var totalFees: Double {
        results.reduce(0.0) { $0 + $1.result.totalFees }
    }

    // MARK: - Comparison Statistics

    private var avgVsBuyHold: Double {
        guard !results.isEmpty else { return 0 }
        let avgStrategyPnl = avgPnl
        let avgBuyHold = results.reduce(0.0) { $0 + $1.result.buyAndHoldPnl } / Double(results.count)
        return avgStrategyPnl - avgBuyHold
    }

    // MARK: - Formatters

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.2f%%", value * 100)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return String(format: "%.1fm", minutes)
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return String(format: "%.1fh", hours)
        } else {
            let days = seconds / 86400
            return String(format: "%.1fd", days)
        }
    }

    private func formatProfitFactor(_ value: Double) -> String {
        if value.isInfinite {
            return "∞"
        }
        return String(format: "%.2fx", value)
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section("Metadata") {
                FormDescriptionField(title: "Name", value: strategyMetadata.name)
                FormDescriptionField(title: "Identifier", value: strategyMetadata.identifier)
                FormDescriptionField(title: "Description", value: strategyMetadata.description)
                FormDescriptionField(title: "Engine Api Version", value: strategyMetadata.runtimeVersion)
            }

            if results.isEmpty {
                Section("Statistics") {
                    Text("No results available. Run a backtest to see statistics.")
                        .foregroundColor(.secondary)
                }
            } else {
                Section("Overview") {
                    FormDescriptionField(title: "Total Results", value: "\(results.count)")
                    FormDescriptionField(title: "Total Trades", value: "\(totalTrades)")
                    FormDescriptionField(title: "Winning Trades", value: "\(winningTrades)")
                    FormDescriptionField(title: "Losing Trades", value: "\(losingTrades)")
                }

                Section("Win Rate") {
                    FormDescriptionField(title: "Best Win Rate", value: formatPercent(bestWinRate))
                    FormDescriptionField(title: "Average Win Rate", value: formatPercent(avgWinRate))
                    FormDescriptionField(title: "Profit Factor", value: formatProfitFactor(profitFactor))
                }

                Section("Profit & Loss") {
                    FormDescriptionField(title: "Best PnL", value: formatCurrency(bestPnl))
                    FormDescriptionField(title: "Worst PnL", value: formatCurrency(worstPnl))
                    FormDescriptionField(title: "Total PnL", value: formatCurrency(totalPnl))
                    FormDescriptionField(title: "Average PnL", value: formatCurrency(avgPnl))
                    FormDescriptionField(title: "Best Single Trade", value: formatCurrency(bestSingleTrade))
                    FormDescriptionField(title: "Worst Single Trade", value: formatCurrency(worstSingleTrade))
                }

                Section("Symbol Performance") {
                    FormDescriptionField(title: "Best Symbol", value: bestSymbol)
                    FormDescriptionField(title: "Worst Symbol", value: worstSymbol)
                }

                Section("Holding Time") {
                    FormDescriptionField(title: "Avg Holding Time", value: formatDuration(avgHoldingTime))
                    FormDescriptionField(title: "Min Holding Time", value: formatDuration(minHoldingTime))
                    FormDescriptionField(title: "Max Holding Time", value: formatDuration(maxHoldingTime))
                }

                Section("Risk") {
                    FormDescriptionField(title: "Avg Max Drawdown", value: formatPercent(avgDrawdown))
                    FormDescriptionField(title: "Worst Drawdown", value: formatPercent(worstDrawdown))
                    FormDescriptionField(title: "Total Fees", value: formatCurrency(totalFees))
                }

                Section("Comparison") {
                    FormDescriptionField(title: "Avg vs Buy & Hold", value: formatCurrency(avgVsBuyHold))
                }
            }
        }
        .formStyle(.grouped)
    }
}
