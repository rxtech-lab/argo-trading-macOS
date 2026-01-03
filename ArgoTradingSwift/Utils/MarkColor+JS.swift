//
//  MarkColor+JS.swift
//  ArgoTradingSwift
//
//  Extensions for converting MarkColor and MarkShape to JavaScript-compatible values
//

import Foundation

extension MarkColor {
    /// Convert MarkColor to a hex string for JavaScript
    func toHexString() -> String {
        switch self {
        case .red:
            return "#ef5350"
        case .green:
            return "#26a69a"
        case .blue:
            return "#2196F3"
        case .yellow:
            return "#FFEB3B"
        case .purple:
            return "#9C27B0"
        case .orange:
            return "#FF9800"
        case .fromRawValue(let hexString):
            // Ensure it starts with #
            if hexString.hasPrefix("#") {
                return hexString
            } else {
                return "#\(hexString)"
            }
        }
    }
}

extension MarkShape {
    /// Convert MarkShape to a JavaScript marker shape name
    func toJSShape() -> String {
        switch self {
        case .circle:
            return "circle"
        case .square:
            return "square"
        case .triangle:
            return "arrowUp"
        }
    }
}
