//
//  BacktestResultDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct BacktestResultDetailView: View {
    @State private var selectedTab: ResultTab = .general
    @State private var generalSubView: GeneralSubView = .info
    @State private var tradesSubView: TradesSubView = .trades
    @State private var showConfigSheet = false
    @State private var configSheetTab: ConfigTab = .backtest

    private enum ConfigTab: String, CaseIterable, Identifiable {
        case backtest
        case strategy

        var id: String { rawValue }

        var localizedName: LocalizedStringKey {
            switch self {
            case .backtest: "Backtest Config"
            case .strategy: "Strategy Config"
            }
        }
    }

    let resultItem: BacktestResultItem

    @Environment(NavigationService.self) private var navigationService

    private var result: BacktestResult {
        resultItem.result
    }

    private var strategyPath: URL? {
        return URL(string: "file://\(result.strategyPath)")
    }

    var body: some View {
        VStack {
            Picker("Select Tab", selection: $selectedTab) {
                ForEach(ResultTab.allCases) { tab in
                    Text(LocalizedStringKey(tab.rawValue)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            tabContent
        }
        .padding(.top, 8)
        .navigationTitle(result.symbol)
        .toolbar {
            subViewToolbarItem
        }
    }

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case .general:
            switch generalSubView {
            case .info:
                buildGeneralTab()
            case .charts:
                BacktestResultChartsView(result: result)
            }
        case .trades:
            switch tradesSubView {
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
            case .marks:
                MarksTableView(
                    filePath: URL(fileURLWithPath: result.marksFilePath),
                    dataFilePath: URL(fileURLWithPath: result.dataFilePath)
                )
            }
        case .logs:
            LogsTableView(
                filePath: URL(fileURLWithPath: result.logFilePath),
                dataFilePath: URL(fileURLWithPath: result.dataFilePath)
            )
        }
    }

    @ToolbarContentBuilder private var subViewToolbarItem: some ToolbarContent {
        switch selectedTab {
        case .general:
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("View", selection: $generalSubView) {
                        ForEach(GeneralSubView.allCases) { subView in
                            Label(LocalizedStringKey(subView.rawValue), systemImage: subView.systemImage)
                                .tag(subView)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(LocalizedStringKey(generalSubView.rawValue), systemImage: generalSubView.systemImage)
                        .labelStyle(.titleAndIcon)
                }
            }
        case .trades:
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("View", selection: $tradesSubView) {
                        ForEach(TradesSubView.allCases) { subView in
                            Label(LocalizedStringKey(subView.rawValue), systemImage: subView.systemImage)
                                .tag(subView)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label(LocalizedStringKey(tradesSubView.rawValue), systemImage: tradesSubView.systemImage)
                        .labelStyle(.titleAndIcon)
                }
            }
        case .logs:
            ToolbarItem(placement: .automatic) { EmptyView() }
        }
    }

    @ViewBuilder func buildGeneralTab() -> some View {
        Form {
            if let portfolioCalculation = result.portfolioCalculation {
                Section("Portfolio") {
                    LabeledContent("Calculation Method") {
                        Text(LocalizedStringKey(portfolioCalculation.displayName))
                    }
                }
            }

            Section("Symbol") {
                LabeledContent("Symbol", value: result.symbol)
                if let parsed = resultItem.parsedFileName {
                    LabeledContent("Date Range", value: parsed.dateRange)
                    LabeledContent("Timespan", value: parsed.timespan)
                }
            }

            Section("Strategy Info") {
                HStack {
                    Text("Name")
                    Spacer()
                    Button {
                        guard let strategyPath = strategyPath else { return }
                        navigationService.push(.backtest(backtest: .strategy(url: strategyPath)))
                    } label: {
                        Text(result.strategy.name)
                    }
                    .disabled(strategyPath == nil)
                    .buttonStyle(.link)
                    .pointerStyle(.link)
                }
                LabeledContent("Identifier", value: result.strategy.id)
                LabeledContent("Version", value: result.strategy.version)
            }

            Section("Profit & Loss") {
                LabeledContent("Total PnL", value: formatCurrency(result.tradePnl.totalPnl))
                LabeledContent("Realized PnL", value: formatCurrency(result.tradePnl.realizedPnl))
                LabeledContent("Unrealized PnL", value: formatCurrency(result.tradePnl.unrealizedPnl))
                LabeledContent("Buy & Hold PnL", value: formatCurrency(result.buyAndHoldPnl))
                LabeledContent("Maximum Profit", value: formatCurrency(result.tradePnl.maximumProfit))
                LabeledContent("Maximum Loss", value: formatCurrency(result.tradePnl.maximumLoss))
                if let median = result.tradePnl.medianPnl {
                    LabeledContent("Median PnL", value: formatCurrency(median))
                }
                if let investment = result.tradePnl.totalInvestment {
                    LabeledContent("Total Investment", value: formatCurrency(investment))
                }
                if let pct = result.tradePnl.pnlPercentage {
                    LabeledContent("PnL %", value: formatPercent(pct))
                }
            }

            if result.initialBalance != nil || result.finalBalance != nil {
                Section("Balance") {
                    if let initial = result.initialBalance {
                        LabeledContent("Initial Balance", value: formatCurrency(initial))
                    }
                    if let final = result.finalBalance {
                        LabeledContent("Final Balance", value: formatCurrency(final))
                    }
                    if let initial = result.initialBalance, let final = result.finalBalance {
                        LabeledContent("Net Change", value: formatCurrency(final - initial))
                    }
                }
            }

            Section("Trade Results") {
                LabeledContent("Number of Trades", value: "\(result.tradeResult.numberOfTrades)")
                if let pairs = result.tradeResult.numberOfTradingPairs {
                    LabeledContent("Trading Pairs", value: "\(pairs)")
                }
                LabeledContent("Winning Trades", value: "\(result.tradeResult.numberOfWinningTrades)")
                LabeledContent("Losing Trades", value: "\(result.tradeResult.numberOfLosingTrades)")
                LabeledContent("Win Rate", value: formatPercent(result.tradeResult.winRate))
                LabeledContent("Max Drawdown", value: formatCurrency(result.tradeResult.maxDrawdown))
            }

            Section("Trade Holding Time") {
                LabeledContent("Minimum", value: DurationFormatter.format(result.tradeHoldingTime.min))
                LabeledContent("Maximum", value: DurationFormatter.format(result.tradeHoldingTime.max))
                LabeledContent("Average", value: DurationFormatter.format(result.tradeHoldingTime.avg))
                if let median = result.tradeHoldingTime.median {
                    LabeledContent("Median", value: DurationFormatter.format(median))
                }
            }

            Section("Fees") {
                LabeledContent("Total Fees", value: formatCurrency(result.totalFees))
            }

            Section("Run Info") {
                LabeledContent("Run Time", value: resultItem.displayTime)
            }

            if result.backtestConfig != nil || result.strategyConfig != nil {
                Section("Configuration") {
                    Button("Show Backtest Config") {
                        configSheetTab = result.backtestConfig != nil ? .backtest : .strategy
                        showConfigSheet = true
                    }
                    .foregroundStyle(.link)
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showConfigSheet) {
            configSheet
        }
    }

    private var configSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Configuration").font(.headline)
                Spacer()
                Button("Done") { showConfigSheet = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Picker("Config", selection: $configSheetTab) {
                ForEach(ConfigTab.allCases) { tab in
                    Text(tab.localizedName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            switch configSheetTab {
            case .backtest:
                JSONView(object: result.backtestConfig ?? [:])
            case .strategy:
                JSONView(object: result.strategyConfig ?? [:])
            }
        }
        .frame(minWidth: 520, minHeight: 420)
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
        return formatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
}
