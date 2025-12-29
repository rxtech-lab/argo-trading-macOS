//
//  AboutView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/29/25.
//

import ArgoTrading
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: Bundle.main.appIcon)
                .resizable()
                .frame(width: 128, height: 128)

            Text(Bundle.main.appName ?? "ArgoTrading")
                .font(.title)
                .fontWeight(.semibold)

            Text("App Version \(Bundle.main.appVersion ?? "1.0") (\(Bundle.main.appBuild ?? "1"))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Link("Engine Version \(getEngineVersion())", destination: .init(string: "https://github.com/rxtech-lab/argo-trading")!)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .underline()
                .pointerStyle(.link)
        }
        .frame(width: 300)
        .padding(24)
    }

    func getEngineVersion() -> String {
        let version = SwiftargoGetBacktestEngineVersion()
        return version
    }
}
