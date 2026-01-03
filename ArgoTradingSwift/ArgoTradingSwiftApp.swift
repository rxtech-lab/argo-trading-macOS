//
//  ArgoTradingSwiftApp.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import SwiftUI

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
            HomeView(document: document.$document)
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

        // Define a custom About window that can be opened once
        Window("About My App", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize) // Make it non-resizable
        .restorationBehavior(.disabled) // Prevent state restoration
    }
}
