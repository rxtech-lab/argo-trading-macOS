//
//  SettingsView.swift
//  ArgoTradingSwift
//
//  Root of the app's Settings scene. Hosts a TabView of preference panes.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            MCPSettingsTab()
                .tabItem {
                    Label("MCP", systemImage: "network")
                }
                .tag("mcp")
        }
        .frame(width: 480, height: 520)
    }
}
