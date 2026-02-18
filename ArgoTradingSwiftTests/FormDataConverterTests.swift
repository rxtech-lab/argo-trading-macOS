//
//  FormDataConverterTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Foundation
import JSONSchemaForm
import Testing
@testable import ArgoTradingSwift

struct FormDataConverterTests {

    // MARK: - Boolean tests

    @Test func booleanTrue_returnsFormDataBoolean() {
        let json: [String: Any] = ["enabled": true]
        let serialized = try! JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: json)) as! [String: Any]
        let result = formDataFromAny(serialized["enabled"]!)
        #expect(result == .boolean(true))
    }

    @Test func booleanFalse_returnsFormDataBoolean() {
        let json: [String: Any] = ["enabled": false]
        let serialized = try! JSONSerialization.jsonObject(with: JSONSerialization.data(withJSONObject: json)) as! [String: Any]
        let result = formDataFromAny(serialized["enabled"]!)
        #expect(result == .boolean(false))
    }

    @Test func booleanFromJSONString_returnsFormDataBoolean() {
        let jsonString = #"{"flag": true}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["flag"]!)
        #expect(result == .boolean(true))
    }

    @Test func booleanFalseFromJSONString_returnsFormDataBoolean() {
        let jsonString = #"{"flag": false}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["flag"]!)
        #expect(result == .boolean(false))
    }

    // MARK: - Number tests

    @Test func integerNumber_returnsFormDataNumber() {
        let jsonString = #"{"count": 42}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["count"]!)
        #expect(result == .number(42.0))
    }

    @Test func doubleNumber_returnsFormDataNumber() {
        let jsonString = #"{"price": 3.14}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["price"]!)
        #expect(result == .number(3.14))
    }

    @Test func zeroNumber_returnsFormDataNumber() {
        let jsonString = #"{"val": 0}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["val"]!)
        #expect(result == .number(0.0))
    }

    @Test func oneNumber_returnsFormDataNumber() {
        let jsonString = #"{"val": 1}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["val"]!)
        #expect(result == .number(1.0))
    }

    // MARK: - Boolean vs Number distinction (the core bug fix)

    @Test func mixedBooleanAndNumber_correctlyDistinguished() {
        let jsonString = #"{"enabled": true, "count": 1, "disabled": false, "zero": 0}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]

        let result = formDataFromAny(dict)

        guard case .object(let properties) = result else {
            Issue.record("Expected .object, got \(result)")
            return
        }

        #expect(properties["enabled"] == .boolean(true))
        #expect(properties["count"] == .number(1.0))
        #expect(properties["disabled"] == .boolean(false))
        #expect(properties["zero"] == .number(0.0))
    }

    // MARK: - String tests

    @Test func string_returnsFormDataString() {
        let result = formDataFromAny("hello")
        #expect(result == .string("hello"))
    }

    @Test func emptyString_returnsFormDataString() {
        let result = formDataFromAny("")
        #expect(result == .string(""))
    }

    // MARK: - Object tests

    @Test func dictionary_returnsFormDataObject() {
        let jsonString = #"{"name": "test", "value": 42}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict)

        guard case .object(let properties) = result else {
            Issue.record("Expected .object, got \(result)")
            return
        }

        #expect(properties["name"] == .string("test"))
        #expect(properties["value"] == .number(42.0))
    }

    @Test func emptyDictionary_returnsEmptyObject() {
        let result = formDataFromAny([String: Any]())
        #expect(result == .object(properties: [:]))
    }

    // MARK: - Array tests

    @Test func array_returnsFormDataArray() {
        let jsonString = #"[1, "two", true]"#
        let arr = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [Any]
        let result = formDataFromAny(arr)

        guard case .array(let items) = result else {
            Issue.record("Expected .array, got \(result)")
            return
        }

        #expect(items.count == 3)
        #expect(items[0] == .number(1.0))
        #expect(items[1] == .string("two"))
        #expect(items[2] == .boolean(true))
    }

    // MARK: - Null tests

    @Test func null_returnsFormDataNull() {
        let jsonString = #"{"val": null}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict["val"]!)
        #expect(result == .null)
    }

    // MARK: - Nested structure

    @Test func nestedStructure_correctlyConverted() {
        let jsonString = #"{"config": {"enableLog": true, "logLevel": 3, "tags": ["a", "b"]}}"#
        let dict = try! JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as! [String: Any]
        let result = formDataFromAny(dict)

        guard case .object(let root) = result,
              case .object(let config) = root["config"] else {
            Issue.record("Expected nested object")
            return
        }

        #expect(config["enableLog"] == .boolean(true))
        #expect(config["logLevel"] == .number(3.0))
        #expect(config["tags"] == .array(items: [.string("a"), .string("b")]))
    }
}
