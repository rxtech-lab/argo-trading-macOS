//
//  BacktestView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//

import SwiftUI

struct BacktestView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(NavigationService.self) var navigationService

    var body: some View {
        NavigationSplitView {
            VStack {
                BacktestSideBar(navigationService: navigationService, document: $document)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Stop", systemImage: "square.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }
            }
        } detail: {
            switch navigationService.path {
            case .backtest(let backtest):
                switch backtest {
                case .data(let url):
                    DataView(url: url)
                default:
                    EmptyView()
                }
            }
        }
    }
}
