//
//  ManageSchemasView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct ManageSchemasView: View {
    @Binding var document: ArgoTradingDocument
    @Environment(SchemaService.self) var schemaService
    @Environment(KeychainService.self) var keychainService
    @Environment(\.dismiss) var dismiss

    @State private var schemaToDelete: Schema?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if document.schemas.isEmpty {
                    ContentUnavailableView {
                        Label("No Schemas", systemImage: "doc.text")
                    } description: {
                        Text("Create a schema to configure your trading strategies.")
                    } actions: {
                        Button("Create Schema") {
                            schemaService.showCreateEditor()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(document.schemas) { schema in
                            SchemaRowView(
                                schema: schema,
                                isSelected: document.selectedSchemaId == schema.id,
                                onEdit: {
                                    schemaService.showEditEditor(for: schema)
                                },
                                onDelete: {
                                    schemaToDelete = schema
                                    showDeleteConfirmation = true
                                },
                                onSelect: {
                                    document.selectedSchemaId = schema.id
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Manage Schemas")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        schemaService.dismissManageSchemas()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        schemaService.showCreateEditor()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Delete Schema", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    schemaToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let schema = schemaToDelete {
                        if schema.hasKeychainFields {
                            keychainService.deleteKeychainValues(
                                identifier: schema.id.uuidString,
                                fieldNames: schema.keychainFieldNames
                            )
                        }
                        document.deleteSchema(schema)
                    }
                    schemaToDelete = nil
                }
            } message: {
                if let schema = schemaToDelete {
                    Text("Are you sure you want to delete \"\(schema.name)\"? This action cannot be undone.")
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct SchemaRowView: View {
    let schema: Schema
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
                        Text(schema.name)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Label(schema.strategyPath, systemImage: "doc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Created \(schema.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            statusBadge(for: schema.runningStatus)

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit schema")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete schema")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(for status: SchemaRunningStatus) -> some View {
        Text(status.title)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.2))
            .foregroundStyle(statusColor(for: status))
            .cornerRadius(4)
    }

    private func statusColor(for status: SchemaRunningStatus) -> Color {
        switch status {
        case .idle: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

#Preview("With Schemas") {
    ManageSchemasView(
        document: .constant(ArgoTradingDocument(
            schemas: [
                Schema(name: "BTC Strategy", strategyPath: "btc_strategy.wasm", runningStatus: .completed),
                Schema(name: "ETH Strategy", strategyPath: "eth_strategy.wasm", runningStatus: .idle),
                Schema(name: "SOL Strategy", strategyPath: "sol_strategy.wasm", runningStatus: .failed)
            ],
            selectedSchemaId: nil
        ))
    )
    .environment(SchemaService())
    .environment(KeychainService())
}

#Preview("Empty") {
    ManageSchemasView(
        document: .constant(ArgoTradingDocument())
    )
    .environment(SchemaService())
    .environment(KeychainService())
}
