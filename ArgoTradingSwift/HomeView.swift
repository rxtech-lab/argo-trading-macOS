//
//  ContentView.swift
//  test-with-go
//
//  Created by Qiwei Li on 4/16/25.
//

import ArgoTrading
import SwiftUI

struct HomeView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(NavigationService.self) var navigationService

    var body: some View {
        NavigationSplitView {
            VStack {
                ModePicker(navigationService: navigationService)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Spacer()
                }

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
            default:
                EmptyView()
            }
        }
        .onAppear {
            print("Data: \(document.dataFolder)")
        }
    }
}
