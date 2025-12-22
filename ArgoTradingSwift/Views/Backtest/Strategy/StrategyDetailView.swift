//
//  StrategyDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct StrategyDetailView: View {
    let url: URL

    var body: some View {
        ContentUnavailableView(
            "Strategy Details",
            systemImage: "gearshape.2",
            description: Text("Strategy configuration will be available here.\n\n\(url.lastPathComponent)")
        )
    }
}
