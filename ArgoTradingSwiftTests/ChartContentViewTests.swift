//
//  ChartContentViewTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/23/25.
//

@testable import ArgoTradingSwift
import Foundation
import SwiftUI
import Testing

// MARK: - ChartTimeInterval.filtered Tests

struct ChartTimeIntervalFilterTests {
    @Test func filteredIntervals_with1SecondMinimum_includesAll() {
        let filtered = ChartTimeInterval.filtered(minimumSeconds: 1)

        #expect(filtered.count == ChartTimeInterval.allCases.count)
        #expect(filtered.contains(.oneSecond))
        #expect(filtered.contains(.oneMinute))
        #expect(filtered.contains(.thirtyMinutes))
        #expect(filtered.contains(.oneHour))
        #expect(filtered.contains(.oneDay))
    }

    @Test func filteredIntervals_with1MinuteMinimum_excludesSeconds() {
        let filtered = ChartTimeInterval.filtered(minimumSeconds: 60)

        #expect(!filtered.contains(.oneSecond))
        #expect(filtered.contains(.oneMinute))
        #expect(filtered.contains(.threeMinutes))
        #expect(filtered.contains(.fiveMinutes))
        #expect(filtered.contains(.fifteenMinutes))
        #expect(filtered.contains(.thirtyMinutes))
        #expect(filtered.contains(.oneHour))
        #expect(filtered.contains(.oneDay))
    }

    @Test func filteredIntervals_with30MinuteMinimum_excludesSmallerIntervals() {
        let filtered = ChartTimeInterval.filtered(minimumSeconds: 1800) // 30 minutes

        #expect(!filtered.contains(.oneSecond))
        #expect(!filtered.contains(.oneMinute))
        #expect(!filtered.contains(.threeMinutes))
        #expect(!filtered.contains(.fiveMinutes))
        #expect(!filtered.contains(.fifteenMinutes))
        #expect(filtered.contains(.thirtyMinutes))
        #expect(filtered.contains(.oneHour))
        #expect(filtered.contains(.twoHours))
        #expect(filtered.contains(.oneDay))
    }

    @Test func filteredIntervals_with1HourMinimum_excludesMinuteIntervals() {
        let filtered = ChartTimeInterval.filtered(minimumSeconds: 3600) // 1 hour

        #expect(!filtered.contains(.oneSecond))
        #expect(!filtered.contains(.oneMinute))
        #expect(!filtered.contains(.thirtyMinutes))
        #expect(filtered.contains(.oneHour))
        #expect(filtered.contains(.twoHours))
        #expect(filtered.contains(.fourHours))
        #expect(filtered.contains(.oneDay))
    }

    @Test func filteredIntervals_with1DayMinimum_excludesHourIntervals() {
        let filtered = ChartTimeInterval.filtered(minimumSeconds: 86400) // 1 day

        #expect(!filtered.contains(.oneSecond))
        #expect(!filtered.contains(.oneHour))
        #expect(!filtered.contains(.twelveHours))
        #expect(filtered.contains(.oneDay))
        #expect(filtered.contains(.threeDays))
        #expect(filtered.contains(.oneWeek))
        #expect(filtered.contains(.oneMonth))
    }

    @Test func filteredForUrl_withValidFilename_filtersCorrectly() {
        // File with 30 minute timespan
        let url = URL(fileURLWithPath: "/tmp/ETHUSDT_2025-04-19_2025-04-21_30_minute.parquet")
        let filtered = ChartTimeInterval.filtered(for: url)

        #expect(!filtered.contains(.oneSecond))
        #expect(!filtered.contains(.oneMinute))
        #expect(!filtered.contains(.fifteenMinutes))
        #expect(filtered.contains(.thirtyMinutes))
        #expect(filtered.contains(.oneHour))
    }

    @Test func filteredForUrl_withInvalidFilename_returnsAll() {
        // File with unparseable name
        let url = URL(fileURLWithPath: "/tmp/invalid_filename.parquet")
        let filtered = ChartTimeInterval.filtered(for: url)

        #expect(filtered.count == ChartTimeInterval.allCases.count)
    }
}

// MARK: - ParsedParquetFileName.timespanSeconds Tests

struct ParsedParquetFileNameTimespanTests {
    @Test func timespanSeconds_parses1Second() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_1_second.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 1)
    }

    @Test func timespanSeconds_parses1Minute() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_1_minute.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 60)
    }

    @Test func timespanSeconds_parses30Minute() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_30_minute.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 1800)
    }

    @Test func timespanSeconds_parses1Hour() {
        let fileName = "BTCUSDT_2024-01-01_2024-01-31_1_hour.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 3600)
    }

    @Test func timespanSeconds_parses1Day() {
        let fileName = "AAPL_2024-01-01_2024-12-31_1_day.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 86400)
    }

    @Test func timespanSeconds_parsesPlurals() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_5_minutes.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 300) // 5 * 60
    }

    @Test func minimumInterval_returns30MinuteForMatchingTimespan() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_30_minute.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.minimumInterval == .thirtyMinutes)
    }

    @Test func minimumInterval_returns1HourForMatchingTimespan() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_1_hour.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.minimumInterval == .oneHour)
    }

    @Test func minimumInterval_returnsNilForUnmatchedTimespan() {
        // 2 minutes doesn't have a matching ChartTimeInterval
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_2_minute.parquet"
        let parsed = ParquetFileNameParser.parse(fileName)

        #expect(parsed?.timespanSeconds == 120)
        #expect(parsed?.minimumInterval == nil) // No 2m interval in ChartTimeInterval
    }
}

// MARK: - ChartTimeInterval Properties Tests

struct ChartTimeIntervalPropertiesTests {
    @Test func allCasesCount() {
        #expect(ChartTimeInterval.allCases.count == 16)
    }

    @Test func secondsProperty_correctForAllCases() {
        #expect(ChartTimeInterval.oneSecond.seconds == 1)
        #expect(ChartTimeInterval.oneMinute.seconds == 60)
        #expect(ChartTimeInterval.threeMinutes.seconds == 180)
        #expect(ChartTimeInterval.fiveMinutes.seconds == 300)
        #expect(ChartTimeInterval.fifteenMinutes.seconds == 900)
        #expect(ChartTimeInterval.thirtyMinutes.seconds == 1800)
        #expect(ChartTimeInterval.oneHour.seconds == 3600)
        #expect(ChartTimeInterval.twoHours.seconds == 7200)
        #expect(ChartTimeInterval.fourHours.seconds == 14400)
        #expect(ChartTimeInterval.sixHours.seconds == 21600)
        #expect(ChartTimeInterval.eightHours.seconds == 28800)
        #expect(ChartTimeInterval.twelveHours.seconds == 43200)
        #expect(ChartTimeInterval.oneDay.seconds == 86400)
        #expect(ChartTimeInterval.threeDays.seconds == 259200)
        #expect(ChartTimeInterval.oneWeek.seconds == 604800)
        #expect(ChartTimeInterval.oneMonth.seconds == 2592000)
    }

    @Test func aggregationMultiplier_nilForStandardIntervals() {
        #expect(ChartTimeInterval.oneSecond.aggregationMultiplier == nil)
        #expect(ChartTimeInterval.oneMinute.aggregationMultiplier == nil)
        #expect(ChartTimeInterval.oneHour.aggregationMultiplier == nil)
        #expect(ChartTimeInterval.oneDay.aggregationMultiplier == nil)
        #expect(ChartTimeInterval.oneWeek.aggregationMultiplier == nil)
        #expect(ChartTimeInterval.oneMonth.aggregationMultiplier == nil)
    }

    @Test func aggregationMultiplier_correctForNonStandardIntervals() {
        #expect(ChartTimeInterval.threeMinutes.aggregationMultiplier == 3)
        #expect(ChartTimeInterval.fiveMinutes.aggregationMultiplier == 5)
        #expect(ChartTimeInterval.fifteenMinutes.aggregationMultiplier == 15)
        #expect(ChartTimeInterval.thirtyMinutes.aggregationMultiplier == 30)
        #expect(ChartTimeInterval.twoHours.aggregationMultiplier == 2)
        #expect(ChartTimeInterval.fourHours.aggregationMultiplier == 4)
        #expect(ChartTimeInterval.sixHours.aggregationMultiplier == 6)
        #expect(ChartTimeInterval.eightHours.aggregationMultiplier == 8)
        #expect(ChartTimeInterval.twelveHours.aggregationMultiplier == 12)
        #expect(ChartTimeInterval.threeDays.aggregationMultiplier == 3)
    }

    @Test func duckDBInterval_mapsToBaseUnits() {
        // Second-based
        #expect(ChartTimeInterval.oneSecond.duckDBInterval == "second")

        // Minute-based (all map to "minute")
        #expect(ChartTimeInterval.oneMinute.duckDBInterval == "minute")
        #expect(ChartTimeInterval.threeMinutes.duckDBInterval == "minute")
        #expect(ChartTimeInterval.thirtyMinutes.duckDBInterval == "minute")

        // Hour-based (all map to "hour")
        #expect(ChartTimeInterval.oneHour.duckDBInterval == "hour")
        #expect(ChartTimeInterval.twoHours.duckDBInterval == "hour")
        #expect(ChartTimeInterval.twelveHours.duckDBInterval == "hour")

        // Day-based
        #expect(ChartTimeInterval.oneDay.duckDBInterval == "day")
        #expect(ChartTimeInterval.threeDays.duckDBInterval == "day")

        // Week/Month
        #expect(ChartTimeInterval.oneWeek.duckDBInterval == "week")
        #expect(ChartTimeInterval.oneMonth.duckDBInterval == "month")
    }

    @Test func displayName_matchesRawValue() {
        for interval in ChartTimeInterval.allCases {
            #expect(interval.displayName == interval.rawValue)
        }
    }
}
