//
//  ContentView.swift
//  test-with-go
//
//  Created by Qiwei Li on 4/16/25.
//

import ArgoTrading
import SwiftUI

struct HomeView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(NavigationService.self) var navigationService
    @Environment(DatasetService.self) var datasetService
    @Environment(StrategyService.self) var strategyService
    @Environment(ToolbarStatusService.self) var toolbarStatusService
    @Environment(BacktestService.self) var backtestService

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR (Left column) - shared across all modes
            VStack {
                BacktestSideBar(navigationService: navigationService, document: $document)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Group {
                        if backtestService.isRunning {
                            Button {
                                backtestService.cancel()
                            } label: {
                                Label("Stop", systemImage: "square.fill")
                            }
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Button {
                                guard let schema = document.selectedSchema,
                                      let datasetURL = document.selectedDatasetURL else { return }
                                backtestService.runBacktest(
                                    schema: schema,
                                    datasetURL: datasetURL,
                                    strategyFolder: document.strategyFolder,
                                    resultFolder: document.resultFolder,
                                    toolbarStatusService: toolbarStatusService
                                )
                            } label: {
                                Label("Start", systemImage: "play.fill")
                            }
                            .disabled(!document.canRunBacktest)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: backtestService.isRunning)
                }
            }
        } content: {
            // CONTENT (Center column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestContentView(navigationService: navigationService)
            case .Trading:
                TradingContentView()
            }
        } detail: {
            // DETAIL (Right column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestDetailView(navigationService: navigationService)
            case .Trading:
                TradingDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SidebarModePicker(navigationService: navigationService)
            }
            ToolbarItemGroup(placement: .principal) {
                ToolbarRunningSectionView(
                    document: $document,
                    status: toolbarStatusService.toolbarRunningStatus,
                    datasetFiles: datasetService.datasetFiles,
                    strategyFiles: strategyService.strategyFiles
                )
                .padding(.horizontal, 8)

                Spacer()

                ToolbarErrorView(toolbarStatus: toolbarStatusService.toolbarRunningStatus)

                Spacer()
            }
        }
        .onAppear {
            datasetService.setDataFolder(document.dataFolder)
        }
        .onChange(of: document.dataFolder) { _, newFolder in
            datasetService.setDataFolder(newFolder)
        }
    }
}

// MARK: - Backtest Content Views

private struct BacktestContentView: View {
    var navigationService: NavigationService

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

private struct BacktestDetailView: View {
    var navigationService: NavigationService

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

// MARK: - Trading Content Views

private struct TradingContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Trading Mode")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Coming Soon")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TradingDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Trading Details",
            systemImage: "info.circle",
            description: Text("Trading details will appear here")
        )
        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
    }
}
