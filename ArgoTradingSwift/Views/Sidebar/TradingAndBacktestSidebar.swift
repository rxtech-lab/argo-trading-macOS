//
//  ModePicker.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct TradingAndBacktestSidebar: View {
    @Environment(DatasetDownloadService.self) var downloadService
    @Environment(StrategyService.self) var strategyService
    @Environment(BacktestService.self) private var backtestService
    @Environment(BacktestResultService.self) private var backtestResultService

    @Bindable var navigationService: NavigationService
    @Binding var document: ArgoTradingDocument
    @State private var pendingStrategyImport: PendingStrategyImport?

    var body: some View {
        @Bindable var strategyVM = strategyService

        VStack(spacing: 0) {
            if navigationService.selectedMode == .Backtest {
                BacktestTabsView(navigationService: navigationService)
            }

            switch navigationService.selectedMode {
            case .Backtest:
                switch navigationService.currentSelectedBacktestTab {
                case .general:
                    List(selection: $navigationService.generalSelection) {
                        BacktestSection(document: $document)
                        StrategySection(document: $document, strategyFolder: document.strategyFolder)
                    }
                case .results:
                    List(selection: $navigationService.resultsSelection) {
                        ResultSection(document: $document, resultFolder: document.resultFolder)
                    }
                }
            case .Trading:
                TradingSideBar(document: $document, navigationService: navigationService)
            }
        }
        .contextMenu {
            Button {
                downloadService.showDownloadView = true
            } label: {
                Label("Download Dataset", systemImage: "arrow.down.circle")
            }
            Button {
                strategyService.showFileImporter = true
            } label: {
                Label("Import Strategy", systemImage: "square.and.arrow.down")
            }
        }
        .fileImporter(
            isPresented: $strategyVM.showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "wasm") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let sourceURL = urls.first {
                    prepareStrategyImport(from: sourceURL)
                }
            case .failure(let error):
                strategyService.error = error.localizedDescription
            }
        }
        .alert("Replace Strategy?", isPresented: .init(
            get: { pendingStrategyImport != nil },
            set: { if !$0 { cancelPendingStrategyImport() } }
        )) {
            Button("Cancel", role: .cancel) {
                cancelPendingStrategyImport()
            }
            Button("Replace", role: .destructive) {
                confirmPendingStrategyImport()
            }
        } message: {
            if let pendingStrategyImport {
                Text("A strategy named \"\(pendingStrategyImport.fileName)\" already exists. Replace it with the imported strategy?")
            }
        }
        .alert("Error", isPresented: .init(
            get: { strategyService.error != nil },
            set: { if !$0 { strategyService.clearError() } }
        )) {
            Button("OK", role: .cancel) {
                strategyService.clearError()
            }
        } message: {
            if let error = strategyService.error {
                Text(error)
            }
        }
        .frame(minWidth: 300)
    }

    private func prepareStrategyImport(from sourceURL: URL) {
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        let importRequest = PendingStrategyImport(
            sourceURL: sourceURL,
            destinationFolder: document.strategyFolder,
            fileName: sourceURL.lastPathComponent,
            didStartAccessingSecurityScopedResource: didStartAccessing
        )

        guard strategyService.strategyExistsForImport(from: sourceURL, to: document.strategyFolder) else {
            strategyService.importStrategy(from: sourceURL, to: document.strategyFolder)
            finishStrategyImport(importRequest)
            return
        }

        pendingStrategyImport = importRequest
    }

    private func confirmPendingStrategyImport() {
        guard let pendingStrategyImport else { return }
        strategyService.importStrategy(
            from: pendingStrategyImport.sourceURL,
            to: pendingStrategyImport.destinationFolder
        )
        finishStrategyImport(pendingStrategyImport)
    }

    private func cancelPendingStrategyImport() {
        guard let pendingStrategyImport else { return }
        finishStrategyImport(pendingStrategyImport)
    }

    private func finishStrategyImport(_ importRequest: PendingStrategyImport) {
        if importRequest.didStartAccessingSecurityScopedResource {
            importRequest.sourceURL.stopAccessingSecurityScopedResource()
        }
        pendingStrategyImport = nil
    }
}

private struct PendingStrategyImport {
    let sourceURL: URL
    let destinationFolder: URL
    let fileName: String
    let didStartAccessingSecurityScopedResource: Bool
}
