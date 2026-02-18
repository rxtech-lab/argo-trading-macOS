//
//  FormDataConverter.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation
import JSONSchemaForm

/// Converts JSON deserialized values (from `JSONSerialization`) to `FormData`.
///
/// JSON booleans are represented as `NSNumber` wrapping `kCFBooleanTrue`/`kCFBooleanFalse`,
/// which can also be cast to `Double` or `Int`. We use identity comparison against the
/// CoreFoundation boolean constants to reliably distinguish booleans from numbers.
func formDataFromAny(_ value: Any) -> FormData {
    switch value {
    case let dict as [String: Any]:
        var properties: [String: FormData] = [:]
        for (key, val) in dict {
            properties[key] = formDataFromAny(val)
        }
        return .object(properties: properties)
    case let array as [Any]:
        return .array(items: array.map { formDataFromAny($0) })
    case let string as String:
        return .string(string)
    case let nsNumber as NSNumber where nsNumber === kCFBooleanTrue || nsNumber === kCFBooleanFalse:
        return .boolean(nsNumber.boolValue)
    case let number as Double:
        return .number(number)
    case let number as Int:
        return .number(Double(number))
    default:
        return .null
    }
}
