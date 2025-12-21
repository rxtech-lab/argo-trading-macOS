//
//  ModePicker.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI

struct BacktestSideBar: View {
    @Environment(DatasetDownloadService.self) var downloadService

    @Bindable var navigationService: NavigationService
    @Binding var document: ArgoTradingDocument

    var body: some View {
        Group {
            List(selection: $navigationService.path) {
                switch navigationService.selectedMode {
                case .Backtest:
                    BacktestSection(dataFolder: document.dataFolder)
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
        }
        .frame(minWidth: 300)
    }
}
