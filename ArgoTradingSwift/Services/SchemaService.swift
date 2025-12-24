//
//  SchemaService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/24/25.
//

import Foundation

@Observable
class SchemaService {
    // UI State
    var showSchemaEditor = false
    var showManageSchemas = false
    var isEditing = false
    var editingSchema: Schema?

    func showCreateEditor() {
        editingSchema = nil
        isEditing = false
        showSchemaEditor = true
    }

    func showEditEditor(for schema: Schema) {
        editingSchema = schema
        isEditing = true
        showSchemaEditor = true
    }

    func dismissEditor() {
        showSchemaEditor = false
        editingSchema = nil
        isEditing = false
    }

    func showManageSchemasSheet() {
        showManageSchemas = true
    }

    func dismissManageSchemas() {
        showManageSchemas = false
    }
}
