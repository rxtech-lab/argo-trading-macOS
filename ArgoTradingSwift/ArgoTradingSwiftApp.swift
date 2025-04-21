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
        WindowGroup {
            HomeView()
                .alertManager(alertService)
                .sheet(isPresented: $datasetDownloadService.showDownloadView) {
                    DatasetDownloadView()
                        .environment(datasetDownloadService)
                }
        }
        .commands {
            DatasetCommand()
        }
        .environment(datasetDownloadService)
        .environment(alertService)
        .environment(modePicker)
        .environment(duckDBService)
    }
}
