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
    
    var body: some View {
        HStack(spacing: 0) {
            // Left panel - Hero section
            VStack(alignment: .leading, spacing: 20) {
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(.blue, .white.opacity(0.8))
                
                Text("Welcome to\nArgo Trading")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineSpacing(4)
                
                Text(
                    "Set up your project to start analyzing the markets with powerful tools and strategies."
                )
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
                .frame(maxWidth: 320)
                
                Spacer()
                
                Text("Version \(appVersion!)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(40)
            .frame(width: 360)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Right panel - Setup form
            VStack(alignment: .leading) {
                Text("Pick an option to get started")
                    .font(.title)
                    .foregroundColor(.primary)
                    .padding()
                
                WelcomeOption(
                    title: "Create a new Project",
                    description:
                    "Start a new project. Choose the folder you want your project to be located",
                    icon: "folder.badge.plus"
                ) {
                    onCreateNewProject()
                }
                
                WelcomeOption(
                    title: "Open an existing Project",
                    description:
                    "Open an existing project. Choose the folder where your project is located",
                    icon: "folder.fill"
                ) {
                    onOpenExistingProject()
                }
            }
            .padding(40)
        }
        .frame(width: 820, height: 520)
    }
}
