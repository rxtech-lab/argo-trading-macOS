//
//  DocumentCommand.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import SwiftUI

struct DocumentCommand: Commands {
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                openWindow(id: "new-document")
            }
        }
    }
}
