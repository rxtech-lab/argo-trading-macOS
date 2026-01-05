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

    @Environment(StrategyCacheService.self) private var strategyCacheService

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
                    StrategyMetadataView(strategyMetadata: metadata, strategyId: metadata.identifier)
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
            await loadStrategyMetadata()
        }
    }

    private func loadStrategyMetadata() async {
        do {
            metadata = try await strategyCacheService.getMetadata(for: url)
        } catch {
            print("Failed to load strategy metadata: \(error)")
            self.error = error.localizedDescription
        }
    }
}
