//
//  ModePicker.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct BacktestSideBar: View {
    @Environment(DatasetDownloadService.self) var downloadService
    @Environment(StrategyService.self) var strategyService
    @Environment(BacktestService.self) private var backtestService

    @Bindable var navigationService: NavigationService
    @Binding var document: ArgoTradingDocument

    var body: some View {
        @Bindable var strategyVM = strategyService

        VStack(spacing: 0) {
            BacktestTabsView(backtestService: backtestService)
            List(selection: $navigationService.path) {
                switch navigationService.selectedMode {
                case .Backtest:
                    switch backtestService.currentBacktestTab {
                    case .general:
                        BacktestSection(document: $document)
                        StrategySection(document: $document, strategyFolder: document.strategyFolder)
                    case .results:
                        EmptyView()
                    }
                default:
                    EmptyView()
                }
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
                    strategyService.importStrategy(from: sourceURL, to: document.strategyFolder)
                }
            case .failure(let error):
                strategyService.error = error.localizedDescription
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
}
