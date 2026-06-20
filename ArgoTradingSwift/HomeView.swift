//
//  ContentView.swift
//  test-with-go
//
//  Created by Qiwei Li on 4/16/25.
//

import AppKit
import ArgoTrading
import SwiftUI

/// When launched for UI testing with `-ArgoMaximizeWindow`, sizes the document
/// window to the screen's visible frame.
///
/// UI tests previously called the green zoom button to get a large window, but
/// native zoom/full-screen on the CI virtual machine shifts the window partly
/// off-screen to the left. That pushes the `NavigationSplitView` sidebar off the
/// left edge, so its rows "exist but are not hittable" (observed at x = -143),
/// which cascades into the chart/backtest UI test failures. Sizing to
/// `visibleFrame` keeps the whole window — sidebar included — on-screen and wide
/// enough to avoid toolbar overflow.
private struct MaximizeWindowForUITests: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        guard ProcessInfo.processInfo.arguments.contains("-ArgoMaximizeWindow") else {
            return view
        }
        Self.maximize(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    /// The window isn't attached when `makeNSView` runs, so poll briefly until it is.
    private static func maximize(_ view: NSView, attempt: Int = 0) {
        guard attempt < 30 else { return }
        guard let window = view.window, let screen = window.screen ?? NSScreen.main else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                maximize(view, attempt: attempt + 1)
            }
            return
        }
        window.setFrame(screen.visibleFrame, display: true)
    }
}

struct HomeView: View {
    @Binding var document: ArgoTradingDocument
    let fileURL: URL?
    @Environment(NavigationService.self) var navigationService
    @Environment(DatasetService.self) var datasetService
    @Environment(StrategyService.self) var strategyService
    @Environment(ToolbarStatusService.self) var toolbarStatusService
    @Environment(BacktestService.self) var backtestService
    @Environment(BacktestResultService.self) var backtestResultService
    @Environment(StrategyCacheService.self) var strategyCacheService
    @Environment(KeychainService.self) var keychainService
    @Environment(TradingService.self) var tradingService
    @Environment(TradingProviderService.self) var tradingProviderService
    @Environment(TradingResultService.self) var tradingResultService
    @Environment(SchemaService.self) var schemaService

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var documentHandleID: UUID?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR (Left column) - shared across all modes
            VStack {
                TradingAndBacktestSidebar(navigationService: navigationService, document: $document)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    switch navigationService.selectedMode {
                    case .Backtest:
                        BacktestStartStopButton(document: $document)
                    case .Trading:
                        TradingStartStopButton(document: $document)
                    }
                }
            }
        } content: {
            // CONTENT (Center column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestContentView(navigationService: navigationService)
            case .Trading:
                TradingContentView(navigationService: navigationService)
            }
        } detail: {
            // DETAIL (Right column)
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestDetailView(navigationService: navigationService)
            case .Trading:
                TradingDetailView(navigationService: navigationService)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(MaximizeWindowForUITests())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SidebarModePicker(navigationService: navigationService)
            }
            if navigationService.canGoBack {
                ToolbarItem(placement: .navigation) {
                    Button {
                        navigationService.pop()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            ToolbarItemGroup(placement: .principal) {
                ToolbarRunningSectionView(
                    document: $document,
                    datasetFiles: datasetService.datasetFiles,
                    strategyFiles: strategyService.strategyFiles,
                    selectedMode: navigationService.selectedMode
                )
                .padding(.horizontal, 8)

                Spacer()

                ToolbarErrorView()

                Spacer()
            }
            if navigationService.selectedMode == .Trading {
                ToolbarItem(placement: .primaryAction) {
                    WalletToolbarButton(document: $document)
                }
            }
        }
        .onAppear {
            if let base = fileURL?.deletingLastPathComponent() {
                document.resolvePaths(relativeTo: base)
            }
            datasetService.setDataFolder(document.dataFolder)
            backtestResultService.setResultFolder(document.resultFolder)
            strategyService.setStrategyFolder(document.strategyFolder)
            tradingResultService.setResultFolder(document.tradingResultFolder)

            let handle = DocumentHandle(
                fileURL: fileURL,
                binding: $document,
                services: DocumentServices(
                    backtest: backtestService,
                    schema: schemaService,
                    strategy: strategyService,
                    dataset: datasetService,
                    toolbar: toolbarStatusService,
                    strategyCache: strategyCacheService,
                    keychain: keychainService,
                    backtestResult: backtestResultService
                )
            )
            DocumentRegistry.shared.register(handle)
            documentHandleID = handle.id
        }
        .onDisappear {
            if let id = documentHandleID {
                DocumentRegistry.shared.unregister(id: id)
                documentHandleID = nil
            }
        }
        .onChange(of: document.dataFolder) { _, newFolder in
            datasetService.setDataFolder(newFolder)
        }
        .onChange(of: document.resultFolder) { _, newFolder in
            backtestResultService.setResultFolder(newFolder)
        }
        .onChange(of: document.strategyFolder) { _, newFolder in
            strategyService.setStrategyFolder(newFolder)
        }
        .onChange(of: document.tradingResultFolder) { _, newFolder in
            tradingResultService.setResultFolder(newFolder)
        }
        .onChange(of: tradingService.liveDataChange) { _, newChange in
            guard let newChange else { return }
            tradingResultService.handleLiveDataChange(newChange)
        }
    }
}
