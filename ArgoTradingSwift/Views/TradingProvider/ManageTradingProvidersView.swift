//
//  ManageTradingProvidersView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct ManageTradingProvidersView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(TradingProviderService.self) var tradingProviderService
    @Environment(KeychainService.self) var keychainService
    @Environment(\.dismiss) var dismiss

    @State private var providerToDelete: TradingProvider?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if document.tradingProviders.isEmpty {
                    ContentUnavailableView {
                        Label("No Trading Providers", systemImage: "network")
                    } description: {
                        Text("Create a trading provider to configure your live trading connections.")
                    } actions: {
                        Button("Create Provider") {
                            tradingProviderService.showCreateEditor()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(document.tradingProviders) { provider in
                            TradingProviderRowView(
                                provider: provider,
                                isSelected: document.selectedTradingProviderId == provider.id,
                                onEdit: {
                                    tradingProviderService.showEditEditor(for: provider)
                                },
                                onDelete: {
                                    providerToDelete = provider
                                    showDeleteConfirmation = true
                                },
                                onSelect: {
                                    document.selectedTradingProviderId = provider.id
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Manage Trading Providers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        tradingProviderService.dismissManageProviders()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        tradingProviderService.showCreateEditor()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Delete Trading Provider", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    providerToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let provider = providerToDelete {
                        if provider.hasKeychainFields {
                            keychainService.deleteKeychainValues(
                                identifier: provider.id.uuidString,
                                fieldNames: provider.keychainFieldNames
                            )
                        }
                        document.deleteTradingProvider(provider)
                    }
                    providerToDelete = nil
                }
            } message: {
                if let provider = providerToDelete {
                    Text("Are you sure you want to delete \"\(provider.name)\"? This action cannot be undone.")
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct TradingProviderRowView: View {
    let provider: TradingProvider
    let isSelected: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.name)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Label(provider.tradingSystemProvider, systemImage: "network")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !provider.marketDataProvider.isEmpty {
                                Label(provider.marketDataProvider, systemImage: "chart.bar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Created \(provider.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit provider")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete provider")
        }
        .padding(.vertical, 4)
    }
}
