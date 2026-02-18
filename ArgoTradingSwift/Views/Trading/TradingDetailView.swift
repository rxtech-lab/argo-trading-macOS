//
//  TradingDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingDetailView: View {
    var navigationService: NavigationService
    @Environment(TradingResultService.self) private var tradingResultService

    var body: some View {
        switch navigationService.tradingSelection {
        case .trading(let trading):
            switch trading {
            case .run(let url):
                if let resultItem = tradingResultService.getResultItem(for: url) {
                    TradingRunDetailView(resultItem: resultItem)
                        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                } else {
                    ContentUnavailableView(
                        "Run Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected trading run could not be found")
                    )
                    .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                }
            case nil:
                tradingEmptyState
            }
        default:
            tradingEmptyState
        }
    }

    private var tradingEmptyState: some View {
        ContentUnavailableView(
            "Trading Details",
            systemImage: "info.circle",
            description: Text("Select a trading run to view details")
        )
        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
    }
}

// MARK: - Trading Run Detail

private enum TradingRunTab: String, CaseIterable, Identifiable {
    case general = "General"
    case trades = "Trades"
    case orders = "Orders"
    case marks = "Marks"
    case logs = "Logs"

    var id: String { rawValue }
}

struct TradingRunDetailView: View {
    let resultItem: TradingResultItem
    @State private var selectedTab: TradingRunTab = .general

    private var result: TradingResult { resultItem.result }

    private var dataFileURL: URL {
        URL(fileURLWithPath: result.marketDataFilePath.isEmpty ? result.tradesFilePath : result.marketDataFilePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Select Tab", selection: $selectedTab) {
                ForEach(TradingRunTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedTab {
            case .general:
                buildGeneralTab()
            case .trades:
                TradesTableView(
                    filePath: URL(fileURLWithPath: result.tradesFilePath),
                    dataFilePath: dataFileURL
                )
            case .orders:
                OrdersTableView(
                    filePath: URL(fileURLWithPath: result.ordersFilePath),
                    dataFilePath: dataFileURL
                )
            case .marks:
                MarksTableView(
                    filePath: URL(fileURLWithPath: result.marksFilePath),
                    dataFilePath: dataFileURL
                )
            case .logs:
                LogsTableView(
                    filePath: URL(fileURLWithPath: result.logsFilePath),
                    dataFilePath: dataFileURL
                )
            }
        }
    }

    @ViewBuilder
    private func buildGeneralTab() -> some View {
        Form {
            Section("Session Info") {
                LabeledContent("Strategy", value: result.strategy.name)
                LabeledContent("Date", value: result.date)
                LabeledContent("Started", value: result.sessionStart.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Last Updated", value: result.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Symbols", value: result.symbols.joined(separator: ", "))
            }

            Section("PnL") {
                LabeledContent("Total PnL", value: formatCurrency(result.tradePnl.totalPnl))
                LabeledContent("Realized PnL", value: formatCurrency(result.tradePnl.realizedPnl))
                LabeledContent("Unrealized PnL", value: formatCurrency(result.tradePnl.unrealizedPnl))
                LabeledContent("Maximum Profit", value: formatCurrency(result.tradePnl.maximumProfit))
                LabeledContent("Maximum Loss", value: formatCurrency(result.tradePnl.maximumLoss))
            }

            Section("Trade Results") {
                LabeledContent("Number of Trades", value: "\(result.tradeResult.numberOfTrades)")
                LabeledContent("Winning Trades", value: "\(result.tradeResult.numberOfWinningTrades)")
                LabeledContent("Losing Trades", value: "\(result.tradeResult.numberOfLosingTrades)")
                LabeledContent("Win Rate", value: String(format: "%.1f%%", result.tradeResult.winRate * 100))
                LabeledContent("Max Drawdown", value: formatCurrency(result.tradeResult.maxDrawdown))
            }

            Section("Holding Time") {
                LabeledContent("Min", value: String(format: "%.1f min", result.tradeHoldingTime.min))
                LabeledContent("Max", value: String(format: "%.1f min", result.tradeHoldingTime.max))
                LabeledContent("Average", value: String(format: "%.1f min", result.tradeHoldingTime.avg))
            }

            Section("Fees") {
                LabeledContent("Total Fees", value: formatCurrency(result.totalFees))
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
}
