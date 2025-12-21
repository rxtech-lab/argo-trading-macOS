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
        Group {
            switch navigationService.selectedMode {
            case .Backtest:
                BacktestView(document: $document)
            case .Trading:
                TradingView(document: $document)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                modePicker
            }
        }
        .onAppear {
            print("Data: \(document.dataFolder)")
        }
    }

    private var modePicker: some View {
        @Bindable var service = navigationService
        return Picker("Mode", selection: $service.selectedMode) {
            ForEach(EditorMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}
