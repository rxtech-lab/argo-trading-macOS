//
//  StrategySection.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import AppKit
import SwiftUI

struct StrategySection: View {
    let strategyFolder: URL

    @Environment(StrategyService.self) var strategyService

    @State private var expandedStrategies = true
    @State private var error: String?
    @State private var showDeleteAlert = false
    @State private var fileToDelete: URL?
    @State private var showRenameAlert = false
    @State private var fileToRename: URL?
    @State private var newFileName: String = ""

    var body: some View {
        DisclosureGroup("Strategies", isExpanded: $expandedStrategies) {
            ForEach(strategyService.strategyFiles, id: \.self) { file in
                NavigationLink(value: NavigationPath.backtest(backtest: .strategy(url: file))) {
                    StrategyFileRow(fileName: file.lastPathComponent)
                        .contextMenu {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([file])
                            } label: {
                                Label("Show in Finder", systemImage: "folder")
                            }

                            Button {
                                fileToRename = file
                                newFileName = file.deletingPathExtension().lastPathComponent
                                showRenameAlert = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
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
        .onAppear {
            strategyService.setStrategyFolder(strategyFolder)
        }
        .onChange(of: strategyFolder) { _, newValue in
            strategyService.setStrategyFolder(newValue)
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) {
                error = nil
            }
        } message: {
            if let error {
                Text(error)
            }
        }
        .alert("Delete Strategy", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                fileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    do {
                        try strategyService.deleteFile(file)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                fileToDelete = nil
            }
        } message: {
            if let file = fileToDelete {
                Text("Are you sure you want to delete \"\(file.lastPathComponent)\"? This action cannot be undone.")
            }
        }
        .alert("Rename Strategy", isPresented: $showRenameAlert) {
            TextField("Strategy name", text: $newFileName)
            Button("Cancel", role: .cancel) {
                fileToRename = nil
                newFileName = ""
            }
            Button("Rename") {
                if let file = fileToRename {
                    do {
                        try strategyService.renameFile(file, to: newFileName)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                fileToRename = nil
                newFileName = ""
            }
        } message: {
            Text("Enter a new name for this strategy.")
        }
    }
}
