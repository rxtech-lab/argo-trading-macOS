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
    var tradingResultFolder: URL
    var schemas: [Schema]
    var selectedSchemaId: UUID?
    var selectedDatasetURL: URL?
    var tradingProviders: [TradingProvider]
    var selectedTradingProviderId: UUID?

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
        tradingResultFolder: URL? = nil,
        schemas: [Schema] = [],
        selectedSchemaId: UUID? = nil,
        selectedDatasetURL: URL? = nil,
        tradingProviders: [TradingProvider] = [],
        selectedTradingProviderId: UUID? = nil
    ) {
        self.dataFolder = dataFolder ?? URL(fileURLWithPath: "/data")
        self.strategyFolder = strategyFolder ?? URL(fileURLWithPath: "/strategy")
        self.resultFolder = resultFolder ?? URL(fileURLWithPath: "/result")
        self.tradingResultFolder = tradingResultFolder ?? URL(fileURLWithPath: "/trading")
        self.schemas = schemas
        self.selectedSchemaId = selectedSchemaId
        self.selectedDatasetURL = selectedDatasetURL
        self.tradingProviders = tradingProviders
        self.selectedTradingProviderId = selectedTradingProviderId
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

    /// Returns true if backtest can be run: schema selected, dataset selected, and strategy path is valid
    var canRunBacktest: Bool {
        guard let schema = selectedSchema else { return false }
        guard selectedDatasetURL != nil else { return false }
        return schema.hasValidStrategyPath
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

    // MARK: - Trading Provider

    var selectedTradingProvider: TradingProvider? {
        guard let id = selectedTradingProviderId else { return nil }
        return tradingProviders.first { $0.id == id }
    }

    mutating func addTradingProvider(_ provider: TradingProvider) {
        tradingProviders.append(provider)
    }

    mutating func updateTradingProvider(_ provider: TradingProvider) {
        if let index = tradingProviders.firstIndex(where: { $0.id == provider.id }) {
            tradingProviders[index] = provider
        }
    }

    mutating func deleteTradingProvider(_ provider: TradingProvider) {
        tradingProviders.removeAll { $0.id == provider.id }
        if selectedTradingProviderId == provider.id {
            selectedTradingProviderId = nil
        }
    }
}

extension ArgoTradingDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case dataFolder, strategyFolder, resultFolder
        case tradingResultFolder
        case schemas, selectedSchemaId, selectedDatasetURL
        case tradingProviders, selectedTradingProviderId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataFolder = try Self.decodePath(container, forKey: .dataFolder)
        strategyFolder = try Self.decodePath(container, forKey: .strategyFolder)
        resultFolder = try Self.decodePath(container, forKey: .resultFolder)
        // Fallback: derive trading folder as sibling of dataFolder
        let defaultTradingFolder = dataFolder.deletingLastPathComponent().appendingPathComponent("trading")
        tradingResultFolder = try Self.decodePathIfPresent(container, forKey: .tradingResultFolder) ?? defaultTradingFolder
        schemas = try container.decode([Schema].self, forKey: .schemas)
        selectedSchemaId = try container.decodeIfPresent(UUID.self, forKey: .selectedSchemaId)
        selectedDatasetURL = try Self.decodePathIfPresent(container, forKey: .selectedDatasetURL)
        tradingProviders = try container.decodeIfPresent([TradingProvider].self, forKey: .tradingProviders) ?? []
        selectedTradingProviderId = try container.decodeIfPresent(UUID.self, forKey: .selectedTradingProviderId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try Self.encodePath(dataFolder, into: &container, forKey: .dataFolder)
        try Self.encodePath(strategyFolder, into: &container, forKey: .strategyFolder)
        try Self.encodePath(resultFolder, into: &container, forKey: .resultFolder)
        try Self.encodePath(tradingResultFolder, into: &container, forKey: .tradingResultFolder)
        try container.encode(schemas, forKey: .schemas)
        try container.encodeIfPresent(selectedSchemaId, forKey: .selectedSchemaId)
        if let selectedDatasetURL {
            try Self.encodePath(selectedDatasetURL, into: &container, forKey: .selectedDatasetURL)
        }
        try container.encode(tradingProviders, forKey: .tradingProviders)
        try container.encodeIfPresent(selectedTradingProviderId, forKey: .selectedTradingProviderId)
    }

    // MARK: - Path codec helpers (support both absolute and relative paths)

    private static func decodePath(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> URL {
        let raw = try container.decode(String.self, forKey: key)
        return try parsePath(raw, forKey: key, in: container)
    }

    private static func decodePathIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> URL? {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        return try parsePath(raw, forKey: key, in: container)
    }

    private static func parsePath(_ raw: String, forKey key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) throws -> URL {
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw)
        }
        if raw.hasPrefix("file:") {
            guard let url = URL(string: raw) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid file URL: \(raw)")
            }
            return url
        }
        // Relative path — preserve raw string as schema-less URL for later resolution.
        guard let url = URL(string: raw) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Invalid relative path: \(raw)")
        }
        return url
    }

    private static func encodePath(_ url: URL, into container: inout KeyedEncodingContainer<CodingKeys>, forKey key: CodingKeys) throws {
        if url.baseURL != nil {
            // Relative URL (schema-less, or resolved-but-still-rebaseable) — preserve
            // the raw relative string so the fixture stays portable on re-save.
            try container.encode(url.relativePath, forKey: key)
        } else if url.isFileURL {
            try container.encode(url.absoluteString, forKey: key)
        } else {
            try container.encode(url.relativePath, forKey: key)
        }
    }

    // MARK: - Relative path resolution

    /// Resolve any relative path fields (those stored as schema-less URLs) against the given base URL.
    /// Absolute file URLs are left untouched. Safe to call multiple times.
    mutating func resolvePaths(relativeTo baseURL: URL) {
        dataFolder = Self.resolved(dataFolder, base: baseURL, isDirectory: true)
        strategyFolder = Self.resolved(strategyFolder, base: baseURL, isDirectory: true)
        resultFolder = Self.resolved(resultFolder, base: baseURL, isDirectory: true)
        tradingResultFolder = Self.resolved(tradingResultFolder, base: baseURL, isDirectory: true)
        if let dataset = selectedDatasetURL {
            selectedDatasetURL = Self.resolved(dataset, base: baseURL, isDirectory: false)
        }
    }

    private static func resolved(_ url: URL, base: URL, isDirectory: Bool) -> URL {
        // Already absolute (no rebaseable base) — leave alone.
        if url.isFileURL && url.baseURL == nil { return url }
        // Build a file URL that retains `base` so filesystem access works while
        // encoding can still recover the original relative string via `.relativePath`.
        let raw = url.relativePath
        return URL(fileURLWithPath: raw, isDirectory: isDirectory, relativeTo: base)
    }
}
