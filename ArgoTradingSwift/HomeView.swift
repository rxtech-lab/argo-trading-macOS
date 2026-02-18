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
    @Environment(BacktestResultService.self) var backtestResultService
    @Environment(StrategyCacheService.self) var strategyCacheService
    @Environment(KeychainService.self) var keychainService
    @Environment(TradingService.self) var tradingService
    @Environment(TradingProviderService.self) var tradingProviderService

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
                    switch navigationService.selectedMode {
                    case .Backtest:
                        Button {
                            if backtestService.isRunning {
                                logger.info("Stopping backtest...")
                                Task {
                                    await backtestService.cancel()
                                }
                            } else {
                                guard let schema = document.selectedSchema,
                                      let datasetURL = document.selectedDatasetURL else { return }
                                Task.detached {
                                    await backtestService.runBacktest(
                                        schema: schema,
                                        datasetURL: datasetURL,
                                        strategyFolder: document.strategyFolder,
                                        resultFolder: document.resultFolder,
                                        toolbarStatusService: toolbarStatusService,
                                        strategyCacheService: strategyCacheService,
                                        keychainService: keychainService
                                    )
                                }
                            }
                        } label: {
                            Label(
                                backtestService.isRunning ? "Stop" : "Start",
                                systemImage: backtestService.isRunning ? "square.fill" : "play.fill"
                            )
                            .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(!backtestService.isRunning && !document.canRunBacktest)
                        .keyboardShortcut("r", modifiers: .command)
                        .animation(.easeInOut(duration: 0.1), value: backtestService.isRunning)
                    case .Trading:
                        Button {
                            if tradingService.isRunning {
                                Task {
                                    await tradingService.stopTrading(toolbarStatusService: toolbarStatusService)
                                }
                            } else {
                                guard let provider = document.selectedTradingProvider,
                                      let schema = document.selectedSchema else { return }
                                Task {
                                    await tradingService.startTrading(
                                        provider: provider,
                                        schema: schema,
                                        keychainService: keychainService,
                                        toolbarStatusService: toolbarStatusService
                                    )
                                }
                            }
                        } label: {
                            Label(
                                tradingService.isRunning ? "Stop" : "Start",
                                systemImage: tradingService.isRunning ? "square.fill" : "play.fill"
                            )
                            .contentTransition(.symbolEffect(.replace))
                        }
                        .disabled(!tradingService.isRunning && (document.selectedTradingProvider == nil || document.selectedSchema == nil))
                        .keyboardShortcut("r", modifiers: .command)
                        .animation(.easeInOut(duration: 0.1), value: tradingService.isRunning)
                    }
                }
            }
        } content: {
            // CONTENT (Center column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestContentView(navigationService: navigationService)
            case .Trading:
                TradingContentView(navigationService: navigationService)
            }
        } detail: {
            // DETAIL (Right column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestDetailView(navigationService: navigationService)
            case .Trading:
                TradingDetailView(navigationService: navigationService)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SidebarModePicker(navigationService: navigationService)
            }
            if navigationService.canGoBack {
                ToolbarItem(placement: .navigation) {
                    Button {
                        navigationService.pop()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItemGroup(placement: .principal) {
                ToolbarRunningSectionView(
                    document: $document,
                    status: toolbarStatusService.toolbarRunningStatus,
                    datasetFiles: datasetService.datasetFiles,
                    strategyFiles: strategyService.strategyFiles,
                    selectedMode: navigationService.selectedMode
                )
                .padding(.horizontal, 8)

                Spacer()

                ToolbarErrorView(toolbarStatus: toolbarStatusService.toolbarRunningStatus)

                Spacer()
            }
        }
        .onAppear {
            datasetService.setDataFolder(document.dataFolder)
            backtestResultService.setResultFolder(document.resultFolder)
        }
        .onChange(of: document.dataFolder) { _, newFolder in
            datasetService.setDataFolder(newFolder)
        }
        .onChange(of: document.resultFolder) { _, newFolder in
            backtestResultService.setResultFolder(newFolder)
        }
    }
}

