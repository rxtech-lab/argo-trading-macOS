//
//  ResultSection.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import AppKit
import SwiftUI

struct ResultSection: View {
    @Binding var document: ArgoTradingDocument
    let resultFolder: URL
    @Environment(BacktestResultService.self) var backtestResultService

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    var body: some View {
        if backtestResultService.sortedDates.isEmpty {
            ContentUnavailableView(
                "No Results",
                systemImage: "chart.bar",
                description: Text("Run a backtest to see results here")
            )
        } else {
            ForEach(backtestResultService.sortedDates, id: \.self) { date in
                Section(Self.dateFormatter.string(from: date)) {
                    if let results = backtestResultService.resultsByDate[date] {
                        ForEach(results) { resultItem in
                            NavigationLink(value: NavigationPath.backtest(backtest: .result(url: resultItem.statsFileURL))) {
                                ResultFileRow(resultItem: resultItem)
                                    .contextMenu {
                                        Button {
                                            let folder = resultItem.statsFileURL.deletingLastPathComponent()
                                            NSWorkspace.shared.activateFileViewerSelecting([folder])
                                        } label: {
                                            Label("Show in Finder", systemImage: "folder")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}
