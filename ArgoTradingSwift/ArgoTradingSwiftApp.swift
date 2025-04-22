//
//  ArgoTradingSwiftApp.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import SwiftUI

@main
struct ArgoTradingSwiftApp: App {
    @State private var datasetDownloadService = DatasetDownloadService()
    @State private var alertService = AlertManager()
    @State private var modePicker = NavigationService()
    @State private var duckDBService = DuckDBService()

    var body: some Scene {
        DocumentGroup(viewing: ArgoTradingDocument.self) { document in
            HomeView(document: document.$document)
                .alertManager(alertService)
                .sheet(isPresented: $datasetDownloadService.showDownloadView) {
                    DatasetDownloadView(document: document.$document)
                        .environment(datasetDownloadService)
                }
        }
        .commands {
            DocumentCommand()
            DatasetCommand()
        }
        .environment(datasetDownloadService)
        .environment(alertService)
        .environment(modePicker)
        .environment(duckDBService)

        WindowGroup(id: "new-document") {
            NewDocumentView()
                .alertManager(alertService)
        }
        .environment(alertService)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
