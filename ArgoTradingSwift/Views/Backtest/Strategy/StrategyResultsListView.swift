//
//  StrategyResultsListView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/4/26.
//

import ArgoTrading
import SwiftUI

struct StrategyResultsListView: View {
    let url: URL

    @Environment(BacktestResultService.self) private var backtestResultService
    @Environment(BacktestService.self) private var backtestService
    @Environment(NavigationService.self) private var navigationService
    @Environment(StrategyCacheService.self) private var strategyCacheService

    @State private var strategyId: String?
    @State private var strategyName: String?
    @State private var isLoadingMetadata = true
    @State private var loadError: String?
    @State private var selectedResultForSheet: BacktestResultItem?

    private var filteredResults: [BacktestResultItem] {
        guard let strategyId else { return [] }
        return backtestResultService.results(forStrategyId: strategyId)
    }

    private var isBacktestRunningForThisStrategy: Bool {
        guard let strategyId else { return false }
        return backtestService.isRunning &&
            backtestService.currentStrategyId == strategyId
    }

    var body: some View {
        VStack {
            if isLoadingMetadata {
                ProgressView("Loading strategy...")
            } else if let error = loadError {
                ContentUnavailableView(
                    "Error Loading Strategy",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                resultsContent
            }
        }
        .task {
            await loadStrategyMetadata()
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if filteredResults.isEmpty && !isBacktestRunningForThisStrategy {
            ContentUnavailableView(
                "No Results",
                systemImage: "chart.bar",
                description: Text("No backtest results for this strategy yet")
            )
        } else {
            List {
                // Running backtest section
                if isBacktestRunningForThisStrategy {
                    Section("Running") {
                        RunningBacktestRow(
                            strategyName: strategyName ?? "Strategy",
                            progress: backtestService.currentProgress,
                            dataFile: backtestService.currentDataFile
                        )
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                // Historical results section
                if !filteredResults.isEmpty {
                    Section("History") {
                        ForEach(filteredResults) { resultItem in
                            Button {
                                selectedResultForSheet = resultItem
                            } label: {
                                StrategyResultRow(resultItem: resultItem)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    navigationService.push(.backtest(backtest: .result(url: resultItem.statsFileURL)))
                                } label: {
                                    Label("Locate in Results", systemImage: "arrow.right.circle")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    deleteResult(resultItem)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .animation(.easeInOut(duration: 0.3), value: isBacktestRunningForThisStrategy)
            .sheet(item: $selectedResultForSheet) { resultItem in
                HSplitView {
                    BacktestChartView(
                        dataFilePath: resultItem.result.dataFilePath,
                        tradesFilePath: resultItem.result.tradesFilePath,
                        marksFilePath: resultItem.result.marksFilePath
                    )
                    .frame(minWidth: 500)

                    BacktestResultDetailView(resultItem: resultItem)
                        .frame(minWidth: 350, maxWidth: 450)
                }
                .frame(minWidth: 1000, minHeight: 600)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            selectedResultForSheet = nil
                        }
                    }
                }
            }
        }
    }

    private func loadStrategyMetadata() async {
        isLoadingMetadata = true

        do {
            let metadata = try await strategyCacheService.getMetadata(for: url)
            strategyId = metadata.identifier
            strategyName = metadata.name
        } catch {
            loadError = error.localizedDescription
        }

        isLoadingMetadata = false
    }

    private func deleteResult(_ resultItem: BacktestResultItem) {
        do {
            try backtestResultService.deleteResult(resultItem)
        } catch {
            print("Failed to delete result: \(error.localizedDescription)")
        }
    }
}
