//
//  SectionHeaderWithHelp.swift
//  ArgoTradingSwift
//

import SwiftUI

struct SectionHeaderWithHelp: View {
    let title: LocalizedStringKey
    let help: LocalizedStringKey

    @State private var showingHelp = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                showingHelp.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                HelpTextPopover(text: help)
            }
        }
    }
}
