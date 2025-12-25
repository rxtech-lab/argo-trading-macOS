//
//  ArgoTradingDocument.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var argoTradingDocument: UTType {
        UTType(importedAs: "lab.rxlab.argo-trading")
    }
}

enum ArgoTradingDocumentError: Error {
    case invalidData
}

struct ArgoTradingDocument: FileDocument {
    var dataFolder: URL
    var strategyFolder: URL
    var resultFolder: URL
    var schemas: [Schema]
    var selectedSchemaId: UUID?
    var selectedDatasetURL: URL?

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            let decoder = JSONDecoder()
            self = try decoder.decode(Self.self, from: data)
            return
        }

        throw ArgoTradingDocumentError.invalidData
    }

    init(
        dataFolder: URL? = nil,
        strategyFolder: URL? = nil,
        resultFolder: URL? = nil,
        schemas: [Schema] = [],
        selectedSchemaId: UUID? = nil,
        selectedDatasetURL: URL? = nil
    ) {
        self.dataFolder = dataFolder ?? URL(fileURLWithPath: "/data")
        self.strategyFolder = strategyFolder ?? URL(fileURLWithPath: "/strategy")
        self.resultFolder = resultFolder ?? URL(fileURLWithPath: "/result")
        self.schemas = schemas
        self.selectedSchemaId = selectedSchemaId
        self.selectedDatasetURL = selectedDatasetURL
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return .init(regularFileWithContents: data)
    }

    static var readableContentTypes: [UTType] { [.argoTradingDocument] }

    var selectedSchema: Schema? {
        guard let id = selectedSchemaId else { return nil }
        return schemas.first { $0.id == id }
    }

    mutating func addSchema(_ schema: Schema) {
        schemas.append(schema)
    }

    mutating func updateSchema(_ schema: Schema) {
        if let index = schemas.firstIndex(where: { $0.id == schema.id }) {
            schemas[index] = schema
        }
    }

    mutating func deleteSchema(_ schema: Schema) {
        schemas.removeAll { $0.id == schema.id }
        if selectedSchemaId == schema.id {
            selectedSchemaId = nil
        }
    }

    mutating func updateStrategyPaths(from oldPath: String, to newPath: String) {
        for index in schemas.indices {
            if schemas[index].strategyPath == oldPath {
                schemas[index].strategyPath = newPath
                schemas[index].updatedAt = Date()
            }
        }
    }

    mutating func clearStrategyPath(for strategyPath: String) {
        for index in schemas.indices {
            if schemas[index].strategyPath == strategyPath {
                schemas[index].strategyPath = ""
                schemas[index].updatedAt = Date()
            }
        }
    }

    /// Returns true if the selected schema has no strategy or the strategy file is missing from the provided list
    func isSchemaStrategyMissing(strategyFiles: [URL]) -> Bool {
        guard let schema = selectedSchema else { return false }
        if schema.strategyPath.isEmpty { return true }
        return !strategyFiles.contains { $0.lastPathComponent == schema.strategyPath }
    }
}

extension ArgoTradingDocument: Codable {}
