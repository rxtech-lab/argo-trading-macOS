//
//  RecentProjectsPanel.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/21/25.
//

import SwiftUI

struct RecentProjectsPanel: View {
    let onSelectProject: (URL) -> Void

    @State private var recentDocuments: [URL] = []
    @State private var selectedURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            if recentDocuments.isEmpty {
                emptyState
            } else {
                List(recentDocuments, id: \.self, selection: $selectedURL) { url in
                    RecentProjectRow(url: url, isSelected: selectedURL == url)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                        .onTapGesture(count: 2) {
                            onSelectProject(url)
                        }
                        .onTapGesture(count: 1) {
                            selectedURL = url
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.5))
        .onAppear {
            loadRecentDocuments()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Recent Projects")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("Projects you open will appear here")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadRecentDocuments() {
        recentDocuments = NSDocumentController.shared.recentDocumentURLs
        selectedURL = recentDocuments.first
    }
}

struct RecentProjectRow: View {
    let url: URL
    let isSelected: Bool

    @State private var isHovered = false

    private var projectIcon: String {
        // Check if it's a folder-type project or file-type
        let ext = url.pathExtension.lowercased()
        if ext == "xcodeproj" || ext == "xcworkspace" {
            return "hammer.fill"
        }
        return "doc.fill"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Project icon
            Image(systemName: projectIcon)
                .font(.system(size: 28))
                .foregroundColor(isSelected ? .white : .blue)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text(shortenedPath(url.deletingLastPathComponent().path))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func shortenedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

#Preview {
    RecentProjectsPanel { url in
        print("Selected: \(url)")
    }
    .frame(width: 340, height: 500)
}
