//
//  BacktestResultDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct BacktestResultDetailView: View {
    @State private var selectedTab: ResultTab = .general
    let resultItem: BacktestResultItem

    private var result: BacktestResult {
        resultItem.result
    }

    var body: some View {
        VStack {
            Picker("Select Tab", selection: $selectedTab) {
                ForEach(ResultTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch selectedTab {
            case .general:
                buildGeneralTab()
            case .trades:
                TradesTableView(
                    filePath: URL(fileURLWithPath: result.tradesFilePath),
                    dataFilePath: URL(fileURLWithPath: result.dataFilePath)
                )
            case .orders:
                OrdersTableView(
                    filePath: URL(fileURLWithPath: result.ordersFilePath),
                    dataFilePath: URL(fileURLWithPath: result.dataFilePath)
                )
            }
        }
        .padding(.top, 8)
        .navigationTitle(result.symbol)
    }

    @ViewBuilder func buildGeneralTab() -> some View {
        Form {
            Section("Symbol") {
                LabeledContent("Symbol", value: result.symbol)
                if let parsed = resultItem.parsedFileName {
                    LabeledContent("Date Range", value: parsed.dateRange)
                    LabeledContent("Timespan", value: parsed.timespan)
                }
            }

            Section("Profit & Loss") {
                LabeledContent("Total PnL", value: formatCurrency(result.tradePnl.totalPnl))
                LabeledContent("Realized PnL", value: formatCurrency(result.tradePnl.realizedPnl))
                LabeledContent("Unrealized PnL", value: formatCurrency(result.tradePnl.unrealizedPnl))
                LabeledContent("Buy & Hold PnL", value: formatCurrency(result.buyAndHoldPnl))
                LabeledContent("Maximum Profit", value: formatCurrency(result.tradePnl.maximumProfit))
                LabeledContent("Maximum Loss", value: formatCurrency(result.tradePnl.maximumLoss))
            }

            Section("Trade Results") {
                LabeledContent("Number of Trades", value: "\(result.tradeResult.numberOfTrades)")
                LabeledContent("Winning Trades", value: "\(result.tradeResult.numberOfWinningTrades)")
                LabeledContent("Losing Trades", value: "\(result.tradeResult.numberOfLosingTrades)")
                LabeledContent("Win Rate", value: formatPercent(result.tradeResult.winRate))
                LabeledContent("Max Drawdown", value: formatPercent(result.tradeResult.maxDrawdown))
            }

            Section("Trade Holding Time") {
                LabeledContent("Minimum", value: formatDuration(result.tradeHoldingTime.min))
                LabeledContent("Maximum", value: formatDuration(result.tradeHoldingTime.max))
                LabeledContent("Average", value: formatDuration(result.tradeHoldingTime.avg))
            }

            Section("Fees") {
                LabeledContent("Total Fees", value: formatCurrency(result.totalFees))
            }

            Section("Run Info") {
                LabeledContent("Run Time", value: resultItem.displayTime)
            }
        }
        .formStyle(.grouped)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    private func formatPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        return formatter.string(from: NSNumber(value: value / 100)) ?? "\(value)%"
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0s"
        }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
