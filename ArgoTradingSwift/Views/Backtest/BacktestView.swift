//
//  BacktestView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//

import SwiftUI

struct BacktestView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(NavigationService.self) var navigationService

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR (Left column)
            VStack {
                BacktestSideBar(navigationService: navigationService, document: $document)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Stop", systemImage: "square.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }
            }
        } content: {
            // CONTENT (Center column - Chart or Strategy)
            switch navigationService.path {
            case .backtest(let backtest):
                switch backtest {
                case .data(let url):
                    ChartContentView(url: url)
                        .frame(minWidth: 400)
                case .strategy(let url):
                    StrategyDetailView(url: url)
                        .frame(minWidth: 400)
                default:
                    chartPlaceholderView
                }
            }
        } detail: {
            // DETAIL (Right column - Table or empty for strategy)
            switch navigationService.path {
            case .backtest(let backtest):
                switch backtest {
                case .data(let url):
                    DataTableView(url: url)
                        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                case .strategy:
                    strategyDetailPlaceholderView
                default:
                    tablePlaceholderView
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Placeholder Views

    private var chartPlaceholderView: some View {
        ContentUnavailableView(
            "No Dataset Selected",
            systemImage: "chart.xyaxis.line",
            description: Text("Select a dataset from the sidebar to view the price chart")
        )
    }

    private var tablePlaceholderView: some View {
        ContentUnavailableView(
            "No Dataset Selected",
            systemImage: "tablecells",
            description: Text("Select a dataset from the sidebar to view the data table")
        )
        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
    }

    private var strategyDetailPlaceholderView: some View {
        ContentUnavailableView(
            "Strategy Configuration",
            systemImage: "slider.horizontal.3",
            description: Text("Strategy parameters and settings will appear here")
        )
        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
    }
}
