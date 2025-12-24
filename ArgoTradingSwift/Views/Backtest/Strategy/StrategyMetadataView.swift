//
//  StrategyMetadataView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import ArgoTrading
import SwiftUI

struct StrategyMetadataView: View {
    let strategyMetadata: SwiftargoStrategyMetadata

    var body: some View {
        Form {
            Section("Metadata") {
                FormDescriptionField(title: "Name", value: strategyMetadata.name)
                FormDescriptionField(title: "Description", value: strategyMetadata.description)
            }

            Section("Statistics") {
                Text("No statistics available.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
