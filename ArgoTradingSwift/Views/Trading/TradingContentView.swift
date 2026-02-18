//
//  TradingContentView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingContentView: View {
    var navigationService: NavigationService
    @Environment(TradingService.self) private var tradingService
    @Environment(TradingResultService.self) private var tradingResultService

    var body: some View {
        content
            .onChange(of: navigationService.tradingSelection) { _, newValue in
                updateActiveRun(for: newValue)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch navigationService.tradingSelection {
        case .trading(let trading):
            switch trading {
            case .run(let url):
                if let resultItem = tradingResultService.getResultItem(for: url) {
                    LiveChartView(
                        runURL: url,
                        marketDataFilePath: resultItem.result.marketDataFilePath,
                        tradesFilePath: resultItem.result.tradesFilePath,
                        marksFilePath: resultItem.result.marksFilePath
                    )
                    .frame(minWidth: 400)
                } else {
                    ContentUnavailableView(
                        "Run Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected trading run could not be found")
                    )
                }
            case nil:
                tradingEmptyState
            }
        default:
            tradingEmptyState
        }
    }

    private func updateActiveRun(for selection: NavigationPath?) {
        guard case .trading(let trading) = selection,
              case .run(let url) = trading,
              let resultItem = tradingResultService.getResultItem(for: url)
        else {
            tradingService.setActiveRun(nil)
            return
        }
        tradingService.setActiveRun(resultItem.result.id)
    }

    private var tradingEmptyState: some View {
        ContentUnavailableView(
            "No Run Selected",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Select a trading run from the sidebar or start a new session")
        )
    }
}
