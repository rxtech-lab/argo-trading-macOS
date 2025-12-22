//
//  StrategyFileRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct StrategyFileRow: View {
    let fileName: String

    private var displayName: String {
        fileName.replacingOccurrences(of: ".wasm", with: "")
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape.2")
                .foregroundStyle(.secondary)
            Text(displayName)
                .truncationMode(.middle)
        }
    }
}
