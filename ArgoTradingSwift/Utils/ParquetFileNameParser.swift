//
//  ParquetFileNameParser.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/21/25.
//

import Foundation

struct ParsedParquetFileName {
    let ticker: String
    let startDate: Date
    let endDate: Date
    let timespan: String

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    var displayName: String {
        let startStr = Self.displayDateFormatter.string(from: startDate)
        let endStr = Self.displayDateFormatter.string(from: endDate)
        return "\(ticker) • \(startStr) - \(endStr) (\(timespan))"
    }

    var dateRange: String {
        let startStr = Self.displayDateFormatter.string(from: startDate)
        let endStr = Self.displayDateFormatter.string(from: endDate)
        return "\(startStr) - \(endStr)"
    }

    /// Convert the timespan string to seconds for comparison
    /// Parses formats like "30 minute", "1 hour", "1 day"
    var timespanSeconds: Int? {
        let components = timespan.split(separator: " ")
        guard components.count == 2,
              let value = Int(components[0]) else {
            return nil
        }

        let unit = String(components[1]).lowercased()
        switch unit {
        case "second", "seconds": return value
        case "minute", "minutes": return value * 60
        case "hour", "hours": return value * 3600
        case "day", "days": return value * 86400
        case "week", "weeks": return value * 604800
        case "month", "months": return value * 2592000
        default: return nil
        }
    }

    /// Get the minimum ChartTimeInterval that matches this data's timespan
    var minimumInterval: ChartTimeInterval? {
        guard let seconds = timespanSeconds else { return nil }
        return ChartTimeInterval.allCases.first { $0.seconds == seconds }
    }
}

enum ParquetFileNameParser {
    private static let dateRegex = /\d{4}-\d{2}-\d{2}/

    static func parse(_ fileName: String) -> ParsedParquetFileName? {
        let name = fileName.replacingOccurrences(of: ".parquet", with: "")
        let components = name.split(separator: "_")

        guard components.count >= 4 else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        var ticker: String?
        var startDate: Date?
        var endDate: Date?
        var timespanComponents: [Substring] = []

        for (index, component) in components.enumerated() {
            let str = String(component)

            if str.wholeMatch(of: dateRegex) != nil {
                if let date = dateFormatter.date(from: str) {
                    if startDate == nil {
                        startDate = date
                    } else if endDate == nil {
                        endDate = date
                    }
                }
            } else if ticker == nil {
                ticker = str
            } else if startDate != nil && endDate != nil {
                timespanComponents.append(contentsOf: components[index...])
                break
            }
        }

        guard let ticker, let startDate, let endDate, !timespanComponents.isEmpty else {
            return nil
        }

        let timespan = timespanComponents.joined(separator: " ")

        return ParsedParquetFileName(
            ticker: ticker,
            startDate: startDate,
            endDate: endDate,
            timespan: timespan
        )
    }

    static func displayName(for fileName: String) -> String {
        if let parsed = parse(fileName) {
            return parsed.displayName
        }
        return fileName.replacingOccurrences(of: ".parquet", with: "")
    }
}
