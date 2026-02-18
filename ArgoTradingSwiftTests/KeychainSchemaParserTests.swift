//
//  KeychainSchemaParserTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Testing

@testable import ArgoTradingSwift

struct KeychainSchemaParserTests {

    @Test func keychainFieldNames_extractsMarkedFields() {
        let schema = """
        {
            "type": "object",
            "properties": {
                "apiKey": {
                    "type": "string",
                    "x-keychain": true
                },
                "secretKey": {
                    "type": "string",
                    "x-keychain": true
                },
                "symbol": {
                    "type": "string"
                }
            }
        }
        """
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields == Set(["apiKey", "secretKey"]))
    }

    @Test func keychainFieldNames_ignoresUnmarkedFields() {
        let schema = """
        {
            "type": "object",
            "properties": {
                "symbol": {
                    "type": "string"
                },
                "interval": {
                    "type": "integer"
                }
            }
        }
        """
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func keychainFieldNames_emptyProperties() {
        let schema = """
        {
            "type": "object",
            "properties": {}
        }
        """
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func keychainFieldNames_invalidJSON() {
        let schema = "not valid json"
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func keychainFieldNames_noPropertiesKey() {
        let schema = """
        {
            "type": "object"
        }
        """
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func keychainFieldNames_nestedObjectIgnored() {
        let schema = """
        {
            "type": "object",
            "properties": {
                "config": {
                    "type": "object",
                    "properties": {
                        "nestedSecret": {
                            "type": "string",
                            "x-keychain": true
                        }
                    }
                }
            }
        }
        """
        // Only top-level properties are inspected
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func keychainFieldNames_xKeychainFalseIgnored() {
        let schema = """
        {
            "type": "object",
            "properties": {
                "apiKey": {
                    "type": "string",
                    "x-keychain": false
                }
            }
        }
        """
        let fields = KeychainSchemaParser.keychainFieldNames(from: schema)
        #expect(fields.isEmpty)
    }

    @Test func buildUiSchema_mapsToPasswordWidget() {
        let fields: Set<String> = ["apiKey", "secretKey"]
        let uiSchema = KeychainSchemaParser.buildUiSchema(keychainFields: fields)

        #expect(uiSchema.count == 2)

        if let apiKeySchema = uiSchema["apiKey"] as? [String: String] {
            #expect(apiKeySchema["ui:widget"] == "password")
        } else {
            Issue.record("Expected apiKey uiSchema to be [String: String]")
        }

        if let secretKeySchema = uiSchema["secretKey"] as? [String: String] {
            #expect(secretKeySchema["ui:widget"] == "password")
        } else {
            Issue.record("Expected secretKey uiSchema to be [String: String]")
        }
    }

    @Test func buildUiSchema_emptyFieldsReturnsEmptyDict() {
        let uiSchema = KeychainSchemaParser.buildUiSchema(keychainFields: [])
        #expect(uiSchema.isEmpty)
    }
}
