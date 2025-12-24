//
//  BacktestSection.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import AppKit
import SwiftUI

struct BacktestSection: View {
    @Environment(DatasetService.self) var datasetService

    @State private var expandedData = true
    @State private var error: String?
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?

    var body: some View {
        DisclosureGroup("Data", isExpanded: $expandedData) {
            ForEach(datasetService.datasetFiles, id: \.self) { file in
                NavigationLink(value: NavigationPath.backtest(backtest: .data(url: file))) {
                    ParquetFileRow(fileName: file.lastPathComponent)
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([file])
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                fileToDelete = file
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .alert("Delete File", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    deleteFile(file)
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete \"\(file.lastPathComponent)\"? This action cannot be undone.")
            }
        }
    }
}

extension BacktestSection {
    func deleteFile(_ file: URL) {
        do {
            try datasetService.deleteFile(file)
        } catch {
            self.error = error.localizedDescription
            print("Error deleting file: \(error.localizedDescription)")
        }
    }
}
