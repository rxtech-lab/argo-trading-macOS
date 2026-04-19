//
//  ArgoTradingSwiftApp.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import LightweightChart
import Sparkle
import SwiftUI

var updaterController: SPUStandardUpdaterController?
let updaterDelegate = UpdaterDelegate()

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Open welcome window on launch
        DispatchQueue.main.async {
            if let app = NSApp {
                for window in app.windows {
                    if window.identifier?.rawValue == "welcome" {
                        window.makeKeyAndOrderFront(nil)
                        return
                    }
                }
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Prevent creating untitled document on launch
        return false
    }
}

@main
struct ArgoTradingSwiftApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var datasetDownloadService = DatasetDownloadService()

    init() {
        // UI tests pass `-ArgoDisableUpdates` (or `ARGO_DISABLE_UPDATES=1` env var)
        // to suppress the Sparkle update prompt, and `-ArgoResetState`
        // (or `ARGO_RESET_STATE=1`) to wipe app-local state before launch.
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let updatesDisabled = args.contains("-ArgoDisableUpdates")
            || env["ARGO_DISABLE_UPDATES"] == "1"

        if args.contains("-ArgoResetState") || env["ARGO_RESET_STATE"] == "1" {
            Self.resetAppState()
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: !updatesDisabled,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        if !updatesDisabled {
            updaterController?.updater.updateCheckInterval = 80
            updaterController?.updater.automaticallyChecksForUpdates = true
        } else {
            updaterController?.updater.automaticallyChecksForUpdates = false
        }
    }

    /// Wipes UserDefaults (including Sparkle's `SU*` keys) and common on-disk
    /// state for this app — recent documents, saved state, Application Support,
    /// Caches. Invoked early in `init()` so services observe a clean baseline.
    private static func resetAppState() {
        let bundleID = Bundle.main.bundleIdentifier ?? "ArgoTradingSwift"
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: bundleID)
        defaults.synchronize()

        let fm = FileManager.default
        let dirsToWipe: [FileManager.SearchPathDirectory] = [
            .applicationSupportDirectory,
            .cachesDirectory,
        ]
        for dir in dirsToWipe {
            if let base = try? fm.url(for: dir, in: .userDomainMask, appropriateFor: nil, create: false) {
                let appDir = base.appendingPathComponent(bundleID, isDirectory: true)
                try? fm.removeItem(at: appDir)
            }
        }

        // NSDocument saved-state dir: ~/Library/Saved Application State/<bundleID>.savedState
        if let lib = try? fm.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let savedState = lib
                .appendingPathComponent("Saved Application State", isDirectory: true)
                .appendingPathComponent("\(bundleID).savedState", isDirectory: true)
            try? fm.removeItem(at: savedState)
        }
    }
    @State private var alertService = AlertManager()
    @State private var modePicker = NavigationService()
    @State private var duckDBService = DuckDBService()
    @State private var strategyService = StrategyService()
    @State private var backtestService = BacktestService()
    @State private var datasetService = DatasetService()
    @State private var schemaService = SchemaService()
    @State private var toolbarStatusService = ToolbarStatusService()
    @State private var backtestResultService = BacktestResultService()
    @State private var lightweightChartsService = LightweightChartService()
    @State private var strategyCacheService = StrategyCacheService()
    @State private var keychainService = KeychainService()
    @State private var tradingProviderService = TradingProviderService()
    @State private var tradingService = TradingService()
    @State private var tradingResultService = TradingResultService()

    @Environment(\.dismissWindow) private var dismissWindow

    var body: some Scene {
        // Welcome Window - opens on app launch
        WindowGroup(id: "welcome") {
            NewDocumentView()
                .alertManager(alertService)
        }
        .environment(alertService)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)

        // Document Window
        DocumentGroup(viewing: ArgoTradingDocument.self) { document in
            HomeView(document: document.$document, fileURL: document.fileURL)
                .alertManager(alertService)
                .frame(minWidth: 1400, minHeight: 600)
                .sheet(isPresented: $datasetDownloadService.showDownloadView) {
                    DatasetDownloadView(document: document.$document)
                }
                .sheet(isPresented: $schemaService.showSchemaEditor) {
                    SchemaEditorView(
                        document: document.$document,
                        isEditing: schemaService.isEditing,
                        existingSchema: schemaService.editingSchema
                    )
                }
                .sheet(isPresented: $schemaService.showManageSchemas) {
                    ManageSchemasView(document: document.$document)
                }
                .sheet(isPresented: $tradingProviderService.showProviderEditor) {
                    TradingProviderEditorView(
                        document: document.$document,
                        isEditing: tradingProviderService.isEditing,
                        existingProvider: tradingProviderService.editingProvider
                    )
                }
                .sheet(isPresented: $tradingProviderService.showManageProviders) {
                    ManageTradingProvidersView(document: document.$document)
                }
                .onAppear {
                    // Dismiss welcome window when document opens
                    dismissWindow(id: "welcome")
                    logger.logLevel = .debug
                }
                .toolbar(removing: .title)
        }
        .commands {
            DocumentCommand()
            DatasetCommand()
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button {
                    openWindow(id: "about")
                } label: {
                    Text("About \(Bundle.main.appName ?? "")")
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController?.checkForUpdates(nil)
                }
            }
        }
        .environment(toolbarStatusService)
        .environment(datasetDownloadService)
        .environment(alertService)
        .environment(modePicker)
        .environment(duckDBService)
        .environment(strategyService)
        .environment(datasetService)
        .environment(backtestService)
        .environment(schemaService)
        .environment(backtestResultService)
        .environment(lightweightChartsService)
        .environment(strategyCacheService)
        .environment(keychainService)
        .environment(tradingProviderService)
        .environment(tradingService)
        .environment(tradingResultService)

        // Define a custom About window that can be opened once
        Window("About My App", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize) // Make it non-resizable
        .restorationBehavior(.disabled) // Prevent state restoration
    }
}
