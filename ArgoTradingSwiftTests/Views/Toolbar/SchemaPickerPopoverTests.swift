//
//  SchemaPickerPopoverTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/25/25.
//

import Testing
import SwiftUI
import ViewInspector
@testable import ArgoTradingSwift

// MARK: - View Inspection Tests

struct SchemaPickerPopoverViewTests {

    func createTestSchemas() -> [Schema] {
        [
            Schema(name: "BTC Strategy", strategyPath: "btc.wasm"),
            Schema(name: "ETH Strategy", strategyPath: "eth.wasm"),
            Schema(name: "SOL Strategy", strategyPath: "sol.wasm")
        ]
    }

    func createDocument(with schemas: [Schema]) -> ArgoTradingDocument {
        var document = ArgoTradingDocument()
        for schema in schemas {
            document.addSchema(schema)
        }
        return document
    }

    @MainActor
    @Test func emptyFilterShowsAllSchemas() throws {
        let schemas = createTestSchemas()
        let document = createDocument(with: schemas)

        let sut = SchemaPickerPopover(
            document: .constant(document),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        // All 3 schemas should be visible
        let btcText = try sut.inspect().find(text: "BTC Strategy")
        #expect(try btcText.string() == "BTC Strategy")

        let ethText = try sut.inspect().find(text: "ETH Strategy")
        #expect(try ethText.string() == "ETH Strategy")

        let solText = try sut.inspect().find(text: "SOL Strategy")
        #expect(try solText.string() == "SOL Strategy")
    }

    @MainActor
    @Test func emptySchemaListShowsNoSchemas() throws {
        let sut = SchemaPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        let noSchemaText = try sut.inspect().find(text: "No schemas")
        #expect(try noSchemaText.string() == "No schemas")
    }

    @MainActor
    @Test func filterTextFieldExists() throws {
        let schemas = createTestSchemas()
        let document = createDocument(with: schemas)

        let sut = SchemaPickerPopover(
            document: .constant(document),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        // Find the TextField
        let textField = try sut.inspect().find(ViewType.TextField.self)
        #expect(throws: Never.self) { try textField.labelView() }
    }

    @MainActor
    @Test func filterTextFieldHasCorrectPlaceholder() throws {
        let schemas = createTestSchemas()
        let document = createDocument(with: schemas)

        let sut = SchemaPickerPopover(
            document: .constant(document),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        let textField = try sut.inspect().find(ViewType.TextField.self)
        let label = try textField.labelView().text().string()
        #expect(label == "Filter")
    }

    @MainActor
    @Test func magnifyingGlassIconExists() throws {
        let schemas = createTestSchemas()
        let document = createDocument(with: schemas)

        let sut = SchemaPickerPopover(
            document: .constant(document),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasMagnifyingGlass = images.contains { image in
            (try? image.actualImage().name() == "magnifyingglass") ?? false
        }
        #expect(hasMagnifyingGlass)
    }

    @MainActor
    @Test func createNewSchemaButtonExists() throws {
        let sut = SchemaPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        let createText = try sut.inspect().find(text: "Create New Schema")
        #expect(try createText.string() == "Create New Schema")
    }

    @MainActor
    @Test func manageSchemasButtonExists() throws {
        let sut = SchemaPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true)
        )
        .environment(SchemaService())

        let manageText = try sut.inspect().find(text: "Manage Schemas")
        #expect(try manageText.string() == "Manage Schemas")
    }
}

// MARK: - Filter Logic Tests

struct SchemaPickerPopoverFilterTests {

    func createTestSchemas() -> [Schema] {
        [
            Schema(name: "BTC Strategy", strategyPath: "btc.wasm"),
            Schema(name: "ETH Strategy", strategyPath: "eth.wasm"),
            Schema(name: "SOL Strategy", strategyPath: "sol.wasm")
        ]
    }

    @Test func filteredSchemasReturnsAllWhenFilterEmpty() {
        let schemas = createTestSchemas()
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "")
        #expect(filtered.count == 3)
    }

    @Test func filteredSchemasMatchesCaseInsensitiveLowercase() {
        let schemas = createTestSchemas()
        // Lowercase "btc" should match "BTC Strategy"
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "btc")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "BTC Strategy")
    }

    @Test func filteredSchemasMatchesCaseInsensitiveUppercase() {
        let schemas = createTestSchemas()
        // Uppercase "BTC" should also match
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "BTC")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "BTC Strategy")
    }

    @Test func filteredSchemasReturnsEmptyWhenNoMatches() {
        let schemas = createTestSchemas()
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "XYZ")
        #expect(filtered.isEmpty)
    }

    @Test func filteredSchemasMatchesPartialText() {
        let schemas = createTestSchemas()
        // "Strategy" should match all 3
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "Strategy")
        #expect(filtered.count == 3)
    }

    @Test func filteredSchemasMatchesSingleSchema() {
        let schemas = createTestSchemas()
        // "ETH" should match only ETH Strategy
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "ETH")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "ETH Strategy")
    }

    @Test func filteredSchemasMatchesMiddleOfName() {
        let schemas = [
            Schema(name: "My BTC Config", strategyPath: "btc.wasm"),
            Schema(name: "ETH Trading", strategyPath: "eth.wasm")
        ]
        // "BTC" should match "My BTC Config"
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "BTC")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "My BTC Config")
    }

    @Test func filteredSchemasIsCaseInsensitiveMixed() {
        let schemas = createTestSchemas()
        // Mixed case "bTc" should match "BTC Strategy"
        let filtered = SchemaPickerPopover.filterSchemas(schemas, with: "bTc")
        #expect(filtered.count == 1)
        #expect(filtered[0].name == "BTC Strategy")
    }
}
