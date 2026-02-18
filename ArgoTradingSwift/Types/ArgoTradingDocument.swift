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
        dataFolder = try container.decode(URL.self, forKey: .dataFolder)
        strategyFolder = try container.decode(URL.self, forKey: .strategyFolder)
        resultFolder = try container.decode(URL.self, forKey: .resultFolder)
        // Fallback: derive trading folder as sibling of dataFolder
        let defaultTradingFolder = dataFolder.deletingLastPathComponent().appendingPathComponent("trading")
        tradingResultFolder = try container.decodeIfPresent(URL.self, forKey: .tradingResultFolder) ?? defaultTradingFolder
        schemas = try container.decode([Schema].self, forKey: .schemas)
        selectedSchemaId = try container.decodeIfPresent(UUID.self, forKey: .selectedSchemaId)
        selectedDatasetURL = try container.decodeIfPresent(URL.self, forKey: .selectedDatasetURL)
        tradingProviders = try container.decodeIfPresent([TradingProvider].self, forKey: .tradingProviders) ?? []
        selectedTradingProviderId = try container.decodeIfPresent(UUID.self, forKey: .selectedTradingProviderId)
    }
}
