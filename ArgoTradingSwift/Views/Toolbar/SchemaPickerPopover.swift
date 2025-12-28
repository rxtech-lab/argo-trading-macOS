//
//  SchemaPickerPopover.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import SwiftUI

struct SchemaPickerPopover: View {
    @Binding var document: ArgoTradingDocument
    @Binding var isPresented: Bool
    @Environment(SchemaService.self) var schemaService

    @State private var schemaFilter = ""
    @State private var isCreateHovered = false
    @State private var isEditHovered = false
    @State private var isManageHovered = false

    private var filteredSchemas: [Schema] {
        Self.filterSchemas(document.schemas, with: schemaFilter)
    }

    static func filterSchemas(_ schemas: [Schema], with filter: String) -> [Schema] {
        if filter.isEmpty {
            return schemas
        }
        return schemas.filter {
            $0.name.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter", text: $schemaFilter)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.bottom, 8)

            if filteredSchemas.isEmpty {
                Text(document.schemas.isEmpty ? "No schemas" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSchemas) { schema in
                            SchemaPickerItemView(
                                schema: schema,
                                isSelected: document.selectedSchemaId == schema.id,
                                onSelect: {
                                    document.selectedSchemaId = schema.id
                                    isPresented = false
                                    schemaFilter = ""
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
                    schemaService.showCreateEditor()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Schema")
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

                if document.selectedSchema != nil {
                    Button {
                        if let schema = document.selectedSchema {
                            schemaService.showEditEditor(for: schema)
                        }
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Current Schema")
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
                    schemaService.showManageSchemasSheet()
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text("Manage Schemas")
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

#Preview {
    SchemaPickerPopover(
        document: .constant(ArgoTradingDocument(
            schemas: [
                Schema(name: "Strategy 1", strategyPath: "strat1.wasm"),
                Schema(name: "Strategy 2", strategyPath: "strat2.wasm", runningStatus: .completed),
                Schema(name: "Strategy 3", strategyPath: "strat3.wasm", runningStatus: .running)
            ]
        )),
        isPresented: .constant(true)
    )
    .environment(SchemaService())
    .padding()
}
