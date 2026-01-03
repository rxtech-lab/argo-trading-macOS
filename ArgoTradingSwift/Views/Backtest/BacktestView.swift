//
//  BacktestView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//

import SwiftUI

struct BacktestContentView: View {
    var navigationService: NavigationService
    @Environment(BacktestResultService.self) var backtestResultService

    var body: some View {
        switch navigationService.path {
        case .backtest(let backtest):
            switch backtest {
            case .data(let url):
                ChartContentView(url: url)
                    .frame(minWidth: 400)
            case .strategy(let url):
                StrategyDetailView(url: url)
                    .frame(minWidth: 400)
            case .result(let url):
                if let resultItem = backtestResultService.getResultItem(for: url) {
                    BacktestChartView(
                        dataFilePath: resultItem.result.dataFilePath,
                        tradesFilePath: resultItem.result.tradesFilePath,
                        marksFilePath: resultItem.result.marksFilePath
                    )
                    .id(url)
                    .frame(minWidth: 500)
                } else {
                    ContentUnavailableView(
                        "Result Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected result could not be loaded")
                    )
                }
            default:
                ContentUnavailableView(
                    "No Dataset Selected",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Select a dataset from the sidebar to view the price chart")
                )
            }
        }
    }
}

struct BacktestDetailView: View {
    var navigationService: NavigationService
    @Environment(BacktestResultService.self) var backtestResultService

    var body: some View {
        switch navigationService.path {
        case .backtest(let backtest):
            switch backtest {
            case .data(let url):
                DataTableView(url: url)
                    .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
            case .strategy:
                ContentUnavailableView(
                    "Strategy Results",
                    systemImage: "slider.horizontal.3",
                    description: Text("Strategy historical results will appear here")
                )
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
            case .result(let url):
                if let resultItem = backtestResultService.getResultItem(for: url) {
                    BacktestResultDetailView(resultItem: resultItem)
                        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                } else {
                    ContentUnavailableView(
                        "Result Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected result could not be loaded")
                    )
                    .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                }
            default:
                ContentUnavailableView(
                    "No Dataset Selected",
                    systemImage: "tablecells",
                    description: Text("Select a dataset from the sidebar to view the data table")
                )
                .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
            }
        }
    }
}
