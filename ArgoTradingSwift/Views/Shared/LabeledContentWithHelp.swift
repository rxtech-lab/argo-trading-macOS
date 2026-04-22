//
//  LabeledContentWithHelp.swift
//  ArgoTradingSwift
//
//  Created by Claude on 4/22/26.
//

import SwiftUI

struct LabeledContentWithHelp<Content: View, HelpContent: View>: View {
    let label: LocalizedStringKey
    let content: Content
    let helpContent: HelpContent?

    @State private var showingHelp = false

    init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) where HelpContent == EmptyView {
        self.label = label
        self.content = content()
        self.helpContent = nil
    }

    init(_ label: LocalizedStringKey, help: LocalizedStringKey, @ViewBuilder content: () -> Content) where HelpContent == Text {
        self.label = label
        self.content = content()
        self.helpContent = Text(help)
            .font(.callout)
            .padding()
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true) as? HelpContent
    }

    init(_ label: LocalizedStringKey, value: String, help: LocalizedStringKey) where Content == Text, HelpContent == Text {
        self.label = label
        self.content = Text(value)
        self.helpContent = Text(help)
            .font(.callout)
            .padding()
            .frame(width: 320)
            .fixedSize(horizontal: false, vertical: true) as? HelpContent
    }

    init(_ label: LocalizedStringKey, value: String, @ViewBuilder helpContent: () -> HelpContent) where Content == Text {
        self.label = label
        self.content = Text(value)
        self.helpContent = helpContent()
    }

    init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder helpContent: () -> HelpContent) {
        self.label = label
        self.content = content()
        self.helpContent = helpContent()
    }

    var body: some View {
        LabeledContent {
            content
        } label: {
            HStack(spacing: 4) {
                Text(label)
                if helpContent != nil {
                    Button {
                        showingHelp.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                        helpContent
                    }
                }
            }
        }
    }
}
