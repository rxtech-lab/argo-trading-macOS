//
//  DurationFormatter.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/28/25.
//

import Foundation

enum DurationFormatter {
    static func format(_ seconds: Double) -> String {
        if seconds == 0 {
            return "0s"
        }

        var remaining = Int(seconds)

        let years = remaining / (365 * 24 * 3600)
        remaining %= (365 * 24 * 3600)

        let months = remaining / (30 * 24 * 3600)
        remaining %= (30 * 24 * 3600)

        let days = remaining / (24 * 3600)
        remaining %= (24 * 3600)

        let hours = remaining / 3600
        remaining %= 3600

        let minutes = remaining / 60
        let secs = remaining % 60

        var components: [String] = []

        if years > 0 { components.append("\(years)y") }
        if months > 0 { components.append("\(months)mo") }
        if days > 0 { components.append("\(days)d") }
        if hours > 0 { components.append("\(hours)h") }
        if minutes > 0 { components.append("\(minutes)m") }
        if secs > 0 || components.isEmpty { components.append("\(secs)s") }

        return components.joined(separator: " ")
    }
}
