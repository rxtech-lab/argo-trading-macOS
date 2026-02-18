//
//  TradingProviderPickerPopover.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingProviderPickerPopover: View {
    @Binding var document: ArgoTradingDocument
    @Binding var isPresented: Bool
    @Environment(TradingProviderService.self) var tradingProviderService

    @State private var providerFilter = ""
    @State private var isCreateHovered = false
    @State private var isEditHovered = false
    @State private var isManageHovered = false

    private var filteredProviders: [TradingProvider] {
        if providerFilter.isEmpty {
            return document.tradingProviders
        }
        return document.tradingProviders.filter {
            $0.name.localizedCaseInsensitiveContains(providerFilter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter", text: $providerFilter)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.bottom, 8)

            if filteredProviders.isEmpty {
                Text(document.tradingProviders.isEmpty ? "No providers" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProviders) { provider in
                            TradingProviderPickerItemView(
                                provider: provider,
                                isSelected: document.selectedTradingProviderId == provider.id,
                                onSelect: {
                                    document.selectedTradingProviderId = provider.id
                                    isPresented = false
                                    providerFilter = ""
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
                .padding(.bottom, 8)
            }

            Divider()
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Button {
                    tradingProviderService.showCreateEditor()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Provider")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isCreateHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCreateHovered = hovering
                    }
                }

                if document.selectedTradingProvider != nil {
                    Button {
                        if let provider = document.selectedTradingProvider {
                            tradingProviderService.showEditEditor(for: provider)
                        }
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Current Provider")
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isEditHovered ? Color.primary.opacity(0.1) : Color.clear)
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isEditHovered = hovering
                        }
                    }
                }

                Button {
                    tradingProviderService.showManageProvidersSheet()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Manage Providers")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isManageHovered ? Color.primary.opacity(0.1) : Color.clear)
                )
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isManageHovered = hovering
                    }
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
}

private struct TradingProviderPickerItemView: View {
    let provider: TradingProvider
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .frame(width: 16)
                } else {
                    Color.clear.frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.body)
                    Text(provider.tradingSystemProvider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
