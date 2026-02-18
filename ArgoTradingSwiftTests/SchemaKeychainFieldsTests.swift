//
//  SchemaKeychainFieldsTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Foundation
import Testing

@testable import ArgoTradingSwift

struct SchemaKeychainFieldsTests {

    @Test func schema_defaultKeychainFieldNames_isEmpty() {
        let schema = Schema(name: "Test Schema")
        #expect(schema.keychainFieldNames.isEmpty)
    }

    @Test func schema_hasKeychainFields_returnsTrueWhenPopulated() {
        let schema = Schema(name: "Test Schema", keychainFieldNames: ["apiKey", "secretKey"])
        #expect(schema.hasKeychainFields)
    }

    @Test func schema_hasKeychainFields_returnsFalseWhenEmpty() {
        let schema = Schema(name: "Test Schema")
        #expect(!schema.hasKeychainFields)
    }

    @Test func schema_backwardsCompatibleDecoding() throws {
        // JSON without keychainFieldNames field (simulating old document)
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "name": "Test",
            "parameters": "",
            "backtestEngineConfig": "",
            "strategyPath": "test.wasm",
            "runningStatus": "idle",
            "createdAt": 0,
            "updatedAt": 0
        }
        """

        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        let schema = try decoder.decode(Schema.self, from: data)

        #expect(schema.keychainFieldNames.isEmpty)
        #expect(!schema.hasKeychainFields)
        #expect(schema.name == "Test")
    }

    @Test func schema_encodingIncludesKeychainFieldNames() throws {
        let schema = Schema(
            name: "Test",
            keychainFieldNames: ["apiKey"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(schema)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(dict?["keychainFieldNames"] as? [String] == ["apiKey"])
    }

    @Test func schema_keychainFieldNamesPreservedInRoundTrip() throws {
        let original = Schema(
            name: "Round Trip Test",
            keychainFieldNames: ["apiKey", "secret"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Schema.self, from: data)

        #expect(decoded.keychainFieldNames == original.keychainFieldNames)
        #expect(decoded.hasKeychainFields)
    }
}
