//
//  WelcomeFirstScreen.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/22/25.
//

import SwiftUI

struct NewDocumentFirstScreen: View {
    let onCreateNewProject: () -> Void
    let onOpenExistingProject: () -> Void
    let onSelectRecentProject: (URL) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Xcode style with centered content
            VStack(spacing: 0) {
                Spacer()

                // App icon
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .foregroundStyle(.blue, Color(.controlBackgroundColor))

                // App name
                Text("Argo Trading")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 16)

                // Version
                Text("Version \(appVersion ?? "1.0")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)

                Spacer()

                // Menu options
                VStack(spacing: 4) {
                    WelcomeOption(
                        title: "Create New Project...",
                        icon: "plus.rectangle.on.folder"
                    ) {
                        onCreateNewProject()
                    }

                    WelcomeOption(
                        title: "Open Existing Project...",
                        icon: "folder"
                    ) {
                        onOpenExistingProject()
                    }
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
            }
            .frame(width: 460)
            .background(Color(.windowBackgroundColor))

            // Right panel - Recent Projects
            RecentProjectsPanel(onSelectProject: onSelectRecentProject)
                .frame(width: 340)
        }
        .frame(width: 800, height: 500)
    }
}
