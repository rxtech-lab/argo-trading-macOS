//
//  StrategyDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import ArgoTrading
import SwiftUI

struct StrategyDetailView: View {
    let url: URL
    @State var error: String?
    @State var metadata: SwiftargoStrategyMetadata?
    @State var selectedTab: StrategyTab = .general

    var body: some View {
        VStack {
            if let metadata = metadata {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(StrategyTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()

                switch selectedTab {
                case .general:
                    StrategyMetadataView(strategyMetadata: metadata)
                case .parameters:
                    StrategyParametersView(jsonSchema: metadata.schema)
                }
            }

            if metadata == nil && error == nil {
                ProgressView {
                    Text("Loading strategy metadata...")
                }
            }

            if let error = error {
                Text("Error loading strategy metadata: \(error)")
            }
        }
        .padding()
        .task {
            Task.detached {
                await loadStrategyMetadata()
            }
        }
    }

    func loadStrategyMetadata() -> Void {
        let strategy = SwiftargoStrategyApi()
        do {
            var abosultePath = url.absoluteString
            abosultePath.replace("file://", with: "")
            metadata = try strategy?.getStrategyMetadata(abosultePath)
        } catch {
            print("Failed to load strategy metadata: \(error)")
            self.error = error.localizedDescription
        }
    }
}
