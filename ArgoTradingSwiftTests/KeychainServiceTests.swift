//
//  KeychainServiceTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Foundation
import Testing

@testable import ArgoTradingSwift

struct KeychainServiceTests {
    // Use a unique test service name to isolate from production keychain items
    private func makeTestService() -> KeychainService {
        KeychainService(serviceNameOverride: "lab.rxlab.argo-trading.test.\(UUID().uuidString)")
    }

    @Test func saveAndRead_roundTrip() {
        let service = makeTestService()
        let key = "test-key"
        let value = "test-value-123"

        let saved = service.save(key: key, value: value)
        #expect(saved)

        let readValue = service.read(key: key)
        #expect(readValue == value)

        // Cleanup
        _ = service.delete(key: key)
    }

    @Test func read_nonExistentKey_returnsNil() {
        let service = makeTestService()
        let readValue = service.read(key: "non-existent-key-\(UUID().uuidString)")
        #expect(readValue == nil)
    }

    @Test func save_overwritesExistingValue() {
        let service = makeTestService()
        let key = "overwrite-key"

        _ = service.save(key: key, value: "first-value")
        _ = service.save(key: key, value: "second-value")

        let readValue = service.read(key: key)
        #expect(readValue == "second-value")

        // Cleanup
        _ = service.delete(key: key)
    }

    @Test func delete_removesValue() {
        let service = makeTestService()
        let key = "delete-key"

        _ = service.save(key: key, value: "to-be-deleted")
        let deleted = service.delete(key: key)
        #expect(deleted)

        let readValue = service.read(key: key)
        #expect(readValue == nil)
    }

    @Test func delete_nonExistentKey_succeeds() {
        let service = makeTestService()
        let deleted = service.delete(key: "non-existent-key-\(UUID().uuidString)")
        #expect(deleted)
    }

    @Test func loadKeychainValues_batchRead() {
        let service = makeTestService()
        let identifier = "test-schema"

        service.saveKeychainValues(identifier: identifier, values: [
            "apiKey": "key123",
            "secretKey": "secret456",
        ])

        let loaded = service.loadKeychainValues(
            identifier: identifier,
            fieldNames: Set(["apiKey", "secretKey", "nonExistent"])
        )

        #expect(loaded["apiKey"] == "key123")
        #expect(loaded["secretKey"] == "secret456")
        #expect(loaded["nonExistent"] == nil)

        // Cleanup
        service.deleteKeychainValues(identifier: identifier, fieldNames: ["apiKey", "secretKey"])
    }

    @Test func saveKeychainValues_batchWrite() {
        let service = makeTestService()
        let identifier = "batch-schema"

        let values = ["field1": "value1", "field2": "value2"]
        service.saveKeychainValues(identifier: identifier, values: values)

        for (field, value) in values {
            let key = KeychainService.keychainKey(identifier: identifier, fieldName: field)
            let readValue = service.read(key: key)
            #expect(readValue == value)
        }

        // Cleanup
        service.deleteKeychainValues(identifier: identifier, fieldNames: Array(values.keys))
    }

    @Test func deleteKeychainValues_removesAllSchemaFields() {
        let service = makeTestService()
        let identifier = "delete-all-schema"

        service.saveKeychainValues(identifier: identifier, values: [
            "key1": "val1",
            "key2": "val2",
        ])

        service.deleteKeychainValues(identifier: identifier, fieldNames: ["key1", "key2"])

        let loaded = service.loadKeychainValues(
            identifier: identifier,
            fieldNames: Set(["key1", "key2"])
        )
        #expect(loaded.isEmpty)
    }

    @Test func keychainKey_format() {
        let key = KeychainService.keychainKey(identifier: "polygon", fieldName: "apiKey")
        #expect(key == "argo-trading.polygon.apiKey")
    }

    @Test func keychainKey_formatWithUUID() {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        let key = KeychainService.keychainKey(identifier: uuid, fieldName: "secretKey")
        #expect(key == "argo-trading.550e8400-e29b-41d4-a716-446655440000.secretKey")
    }
}
