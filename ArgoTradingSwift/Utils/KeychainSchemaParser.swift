//
//  KeychainSchemaParser.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

enum KeychainSchemaParser {
    /// Extract property names that have `"x-keychain": true` from a raw JSON schema string.
    /// Only inspects top-level properties (not nested objects).
    static func keychainFieldNames(from schemaString: String) -> Set<String> {
        guard let data = schemaString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let properties = json["properties"] as? [String: Any]
        else {
            return []
        }

        var fields: Set<String> = []
        for (name, value) in properties {
            if let propDict = value as? [String: Any],
               let xKeychain = propDict["x-keychain"] as? Bool,
               xKeychain
            {
                fields.insert(name)
            }
        }
        return fields
    }

    /// Extract property order from a JSON schema string, preserving the order as it appears in the JSON.
    /// Uses JSONSerialization with fragmentsAllowed to parse, then manually extracts key order from the raw string.
    static func propertyOrder(from schemaString: String) -> [String]? {
        guard let data = schemaString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let properties = json["properties"] as? [String: Any]
        else {
            return nil
        }

        // Find the "properties" object in the raw string and extract key order
        guard let propertiesRange = schemaString.range(of: "\"properties\"") else {
            return nil
        }

        let afterProperties = schemaString[propertiesRange.upperBound...]
        guard let braceStart = afterProperties.firstIndex(of: "{") else {
            return nil
        }

        // Extract keys in order by finding quoted strings followed by ":"
        var orderedKeys: [String] = []
        let propertyKeys = Set(properties.keys)
        var searchStart = braceStart
        var braceDepth = 0

        for index in afterProperties[braceStart...].indices {
            let char = afterProperties[index]
            if char == "{" {
                braceDepth += 1
            } else if char == "}" {
                braceDepth -= 1
                if braceDepth == 0 {
                    break
                }
            } else if char == "\"" && braceDepth == 1 {
                // We're at the start of a potential property key
                let keyStart = afterProperties.index(after: index)
                if let keyEnd = afterProperties[keyStart...].firstIndex(of: "\"") {
                    let key = String(afterProperties[keyStart..<keyEnd])
                    if propertyKeys.contains(key) && !orderedKeys.contains(key) {
                        orderedKeys.append(key)
                    }
                }
            }
        }

        return orderedKeys.isEmpty ? nil : orderedKeys
    }

    /// Build a uiSchema dict that maps keychain fields to password widgets and optionally includes field order.
    /// Format: `{ "fieldName": { "ui:widget": "password" }, "ui:order": ["field1", "field2"] }`
    static func buildUiSchema(keychainFields: Set<String>, propertyOrder: [String]? = nil) -> [String: Any] {
        var uiSchema: [String: Any] = [:]
        for field in keychainFields {
            uiSchema[field] = ["ui:widget": "password"]
        }
        if let order = propertyOrder {
            uiSchema["ui:order"] = order
        }
        return uiSchema
    }
}
