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
    @Environment(StrategyImportViewModel.self) var strategyImportViewModel
    @Environment(BacktestService.self) private var backtestService

    @Bindable var navigationService: NavigationService
    @Binding var document: ArgoTradingDocument

    var body: some View {
        @Bindable var strategyVM = strategyImportViewModel

        VStack(spacing: 0) {
            BacktestTabsView(backtestService: backtestService)
            List(selection: $navigationService.path) {
                switch navigationService.selectedMode {
                case .Backtest:
                    switch backtestService.currentBacktestTab {
                    case .general:
                        BacktestSection()
                        StrategySection(strategyFolder: document.strategyFolder)
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
                strategyImportViewModel.showFileImporter = true
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
                    strategyImportViewModel.importStrategy(from: sourceURL, to: document.strategyFolder)
                }
            case .failure(let error):
                strategyImportViewModel.error = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .init(
            get: { strategyImportViewModel.error != nil },
            set: { if !$0 { strategyImportViewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {
                strategyImportViewModel.clearError()
            }
        } message: {
            if let error = strategyImportViewModel.error {
                Text(error)
            }
        }
        .frame(minWidth: 300)
    }
}
