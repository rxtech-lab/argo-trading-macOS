//
//  TradingSideBar.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import AppKit
import SwiftUI

struct TradingSideBar: View {
    @Binding var document: ArgoTradingDocument
    @Bindable var navigationService: NavigationService
    @Environment(TradingResultService.self) private var tradingResultService

    @State private var showDeleteAlert = false
    @State private var folderToDelete: URL?

    var body: some View {
        List(selection: $navigationService.tradingSelection) {
            if tradingResultService.sortedDates.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "chart.bar",
                    description: Text("Run a live trading session to see results here")
                )
            } else {
                ForEach(tradingResultService.sortedDates, id: \.self) { date in
                    Section(date) {
                        if let results = tradingResultService.resultsByDate[date] {
                            ForEach(results) { resultItem in
                                NavigationLink(value: NavigationPath.trading(trading: .run(url: resultItem.statsFileURL))) {
                                    TradingRunRow(resultItem: resultItem)
                                }
                                .contextMenu {
                                    Button {
                                        let folder = resultItem.statsFileURL.deletingLastPathComponent()
                                        NSWorkspace.shared.activateFileViewerSelecting([folder])
                                    } label: {
                                        Label("Show in Finder", systemImage: "folder")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        folderToDelete = resultItem.statsFileURL.deletingLastPathComponent()
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
        .alert("Delete Result", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    do {
                        try FileManager.default.removeItem(at: folder)
                    } catch {
                        print("Error deleting folder: \(error.localizedDescription)")
                    }
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
