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
    @State private var folderToDelete: URL?

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
                                        .contextMenu {
                                            Button {
                                                let folder = resultItem.statsFileURL.deletingLastPathComponent()
                                                NSWorkspace.shared.activateFileViewerSelecting([folder])
                                            } label: {
                                                Label("Show in Finder", systemImage: "folder")
                                            }

                                            Divider()

                                            Button(role: .destructive) {
                                                folderToDelete = getTimestampFolder(from: resultItem.statsFileURL)
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
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    deleteFolder(folder)
                }
                folderToDelete = nil
            }
        } message: {
            if let folder = folderToDelete {
                Text("Are you sure you want to delete \"\(folder.lastPathComponent)\"? This action cannot be undone.")
            }
        }
    }
}

extension ResultSection {
    private func getTimestampFolder(from statsFileURL: URL) -> URL {
        // Path: result/20251227_092739/config_0/BTCUSDT_.../stats.yaml
        // Navigate up 3 levels: stats.yaml -> dataset -> config -> timestamp
        statsFileURL
            .deletingLastPathComponent()  // remove stats.yaml
            .deletingLastPathComponent()  // remove dataset folder
            .deletingLastPathComponent()  // remove config folder -> timestamp folder
    }

    private func deleteFolder(_ folder: URL) {
        do {
            try FileManager.default.removeItem(at: folder)
            // FolderMonitor in BacktestResultService will auto-refresh
        } catch {
            print("Error deleting folder: \(error.localizedDescription)")
        }
    }
}
