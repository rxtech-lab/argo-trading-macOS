//
//  TradingView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//

import SwiftUI

struct TradingView: View {
    @Binding var document: ArgoTradingDocument

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Trading Mode")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Coming Soon")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
