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

    var body: some Scene {
        WindowGroup {
            ContentView()
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
    }
}
