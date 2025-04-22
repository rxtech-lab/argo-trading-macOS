//
//  DocumentCommand.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import SwiftUI

struct DocumentCommand: Commands {
    @Environment(\.openWindow) var openWindow
    @Environment(\.openDocument) var openDocument

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New project") {
                openWindow(id: "new-document")
            }

            Button("Open project") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.allowedContentTypes = [.argoTradingDocument]
                panel.begin { result in
                    if result == .OK, let url = panel.url {
                        Task {
                            try await openDocument(at: url)
                        }
                    }
                }
            }
        }
    }
}
