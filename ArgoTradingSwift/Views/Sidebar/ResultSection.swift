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

    @State private var showDeleteAlert = false
    @State private var resultItemToDelete: BacktestResultItem?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    var body: some View {
        Group {
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
                                        .id(resultItem.id)
                                        .accessibilityIdentifier("argo.resultRow")
                                        .contextMenu {
                                            Button {
                                                let folder = resultItem.statsFileURL.deletingLastPathComponent()
                                                NSWorkspace.shared.activateFileViewerSelecting([folder])
                                            } label: {
                                                Label("Show in Finder", systemImage: "folder")
                                            }

                                            Divider()

                                            Button(role: .destructive) {
                                                resultItemToDelete = resultItem
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("Delete Result", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                resultItemToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let item = resultItemToDelete {
                    do {
                        try backtestResultService.deleteResult(item)
                    } catch {
                        print("Error deleting result: \(error.localizedDescription)")
                    }
                }
                resultItemToDelete = nil
            }
        } message: {
            if let item = resultItemToDelete {
                Text("Are you sure you want to delete this result run from \(Self.dateFormatter.string(from: item.runTimestamp))? This action cannot be undone.")
            }
        }
    }
}
