//
//  ArgoTradingDocumentTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/25/25.
//

import Testing
import Foundation
@testable import ArgoTradingSwift

struct ArgoTradingDocumentTests {

    // MARK: - clearStrategyPath Tests

    @Test func clearStrategyPathClearsMatchingSchemas() {
        var document = ArgoTradingDocument()
        let schema1 = Schema(name: "Schema 1", strategyPath: "test.wasm")
        let schema2 = Schema(name: "Schema 2", strategyPath: "test.wasm")
        document.addSchema(schema1)
        document.addSchema(schema2)

        document.clearStrategyPath(for: "test.wasm")

        #expect(document.schemas[0].strategyPath == "")
        #expect(document.schemas[1].strategyPath == "")
    }

    @Test func clearStrategyPathDoesNotAffectOtherSchemas() {
        var document = ArgoTradingDocument()
        let schema1 = Schema(name: "Schema 1", strategyPath: "test.wasm")
        let schema2 = Schema(name: "Schema 2", strategyPath: "other.wasm")
        document.addSchema(schema1)
        document.addSchema(schema2)

        document.clearStrategyPath(for: "test.wasm")

        #expect(document.schemas[0].strategyPath == "")
        #expect(document.schemas[1].strategyPath == "other.wasm")
    }

    @Test func clearStrategyPathUpdatesTimestamp() throws {
        var document = ArgoTradingDocument()
        let originalDate = Date(timeIntervalSince1970: 0)
        let schema = Schema(
            name: "Schema 1",
            strategyPath: "test.wasm",
            updatedAt: originalDate
        )
        document.addSchema(schema)

        document.clearStrategyPath(for: "test.wasm")

        #expect(document.schemas[0].updatedAt > originalDate)
    }

    @Test func clearStrategyPathWithNoMatchingSchemas() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Schema 1", strategyPath: "other.wasm")
        document.addSchema(schema)

        document.clearStrategyPath(for: "nonexistent.wasm")

        #expect(document.schemas[0].strategyPath == "other.wasm")
    }

    // MARK: - Schema.hasValidStrategyPath Tests

    @Test func schemaHasValidStrategyPathReturnsTrueForNonEmpty() {
        let schema = Schema(name: "Test", strategyPath: "test.wasm")

        #expect(schema.hasValidStrategyPath == true)
    }

    @Test func schemaHasValidStrategyPathReturnsFalseForEmpty() {
        let schema = Schema(name: "Test", strategyPath: "")

        #expect(schema.hasValidStrategyPath == false)
    }

    // MARK: - selectedDatasetURL Tests

    @Test func selectedDatasetURLCanBeSet() {
        var document = ArgoTradingDocument()
        let testURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        document.selectedDatasetURL = testURL

        #expect(document.selectedDatasetURL == testURL)
    }

    @Test func selectedDatasetURLCanBeCleared() {
        var document = ArgoTradingDocument()
        document.selectedDatasetURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        document.selectedDatasetURL = nil

        #expect(document.selectedDatasetURL == nil)
    }

    // MARK: - selectedSchema Tests

    @Test func selectedSchemaReturnsCorrectSchema() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id

        #expect(document.selectedSchema?.id == schema.id)
        #expect(document.selectedSchema?.name == "Test Schema")
    }

    @Test func selectedSchemaReturnsNilWhenNoSelection() {
        let document = ArgoTradingDocument()

        #expect(document.selectedSchema == nil)
    }

    @Test func selectedSchemaReturnsNilWhenIdNotFound() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = UUID() // Different ID

        #expect(document.selectedSchema == nil)
    }

    // MARK: - deleteSchema Tests

    @Test func deleteSchemaRemovesSchema() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)

        document.deleteSchema(schema)

        #expect(document.schemas.isEmpty)
    }

    @Test func deleteSchemaCleasSelectedSchemaIdWhenDeleted() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id

        document.deleteSchema(schema)

        #expect(document.selectedSchemaId == nil)
    }

    @Test func deleteSchemaDoesNotClearSelectedSchemaIdWhenDifferent() {
        var document = ArgoTradingDocument()
        let schema1 = Schema(name: "Schema 1", strategyPath: "test1.wasm")
        let schema2 = Schema(name: "Schema 2", strategyPath: "test2.wasm")
        document.addSchema(schema1)
        document.addSchema(schema2)
        document.selectedSchemaId = schema2.id

        document.deleteSchema(schema1)

        #expect(document.selectedSchemaId == schema2.id)
        #expect(document.schemas.count == 1)
    }

    // MARK: - updateStrategyPaths Tests

    @Test func updateStrategyPathsUpdatesMatchingSchemas() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "old.wasm")
        document.addSchema(schema)

        document.updateStrategyPaths(from: "old.wasm", to: "new.wasm")

        #expect(document.schemas[0].strategyPath == "new.wasm")
    }

    @Test func updateStrategyPathsDoesNotAffectOtherSchemas() {
        var document = ArgoTradingDocument()
        let schema1 = Schema(name: "Schema 1", strategyPath: "old.wasm")
        let schema2 = Schema(name: "Schema 2", strategyPath: "other.wasm")
        document.addSchema(schema1)
        document.addSchema(schema2)

        document.updateStrategyPaths(from: "old.wasm", to: "new.wasm")

        #expect(document.schemas[0].strategyPath == "new.wasm")
        #expect(document.schemas[1].strategyPath == "other.wasm")
    }

    // MARK: - isSchemaStrategyMissing Tests

    @Test func isSchemaStrategyMissingReturnsFalseWhenNoSchemaSelected() {
        let document = ArgoTradingDocument()
        let strategyFiles = [URL(fileURLWithPath: "/strategies/test.wasm")]

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == false)
    }

    @Test func isSchemaStrategyMissingReturnsTrueWhenStrategyPathIsEmpty() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        let strategyFiles = [URL(fileURLWithPath: "/strategies/test.wasm")]

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == true)
    }

    @Test func isSchemaStrategyMissingReturnsTrueWhenStrategyFileNotFound() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "missing.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        let strategyFiles = [URL(fileURLWithPath: "/strategies/other.wasm")]

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == true)
    }

    @Test func isSchemaStrategyMissingReturnsFalseWhenStrategyFileExists() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        let strategyFiles = [URL(fileURLWithPath: "/strategies/test.wasm")]

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == false)
    }

    @Test func isSchemaStrategyMissingMatchesByLastPathComponent() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "my_strategy.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        // Different directory path but same filename
        let strategyFiles = [URL(fileURLWithPath: "/some/other/path/my_strategy.wasm")]

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == false)
    }

    @Test func isSchemaStrategyMissingReturnsTrueWithEmptyStrategyFilesList() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        let strategyFiles: [URL] = []

        #expect(document.isSchemaStrategyMissing(strategyFiles: strategyFiles) == true)
    }

    // MARK: - canRunBacktest Tests

    @Test func canRunBacktestReturnsFalseWhenNoSchemaSelected() {
        var document = ArgoTradingDocument()
        document.selectedDatasetURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        #expect(document.canRunBacktest == false)
    }

    @Test func canRunBacktestReturnsFalseWhenNoDatasetSelected() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id

        #expect(document.canRunBacktest == false)
    }

    @Test func canRunBacktestReturnsFalseWhenStrategyPathIsEmpty() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        document.selectedDatasetURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        #expect(document.canRunBacktest == false)
    }

    @Test func canRunBacktestReturnsTrueWhenAllConditionsMet() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = schema.id
        document.selectedDatasetURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        #expect(document.canRunBacktest == true)
    }

    @Test func canRunBacktestReturnsFalseWhenSchemaIdNotFound() {
        var document = ArgoTradingDocument()
        let schema = Schema(name: "Test Schema", strategyPath: "test.wasm")
        document.addSchema(schema)
        document.selectedSchemaId = UUID() // Different ID
        document.selectedDatasetURL = URL(fileURLWithPath: "/path/to/dataset.parquet")

        #expect(document.canRunBacktest == false)
    }
}
