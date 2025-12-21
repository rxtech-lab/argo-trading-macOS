//
//  ParquetFileNameParserTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/21/25.
//

import Testing
import Foundation
@testable import ArgoTradingSwift

struct ParquetFileNameParserTests {

    @Test func validFormatWithMinuteTimespan() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_1_minute.parquet"
        let result = ParquetFileNameParser.parse(fileName)

        #expect(result != nil)
        #expect(result?.ticker == "ETHUSDT")
        #expect(result?.timespan == "1 minute")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        #expect(result?.startDate == dateFormatter.date(from: "2025-04-19"))
        #expect(result?.endDate == dateFormatter.date(from: "2025-04-21"))
    }

    @Test func validFormatWithDayTimespan() {
        let fileName = "AAPL_2024-01-01_2024-12-31_1_day.parquet"
        let result = ParquetFileNameParser.parse(fileName)

        #expect(result != nil)
        #expect(result?.ticker == "AAPL")
        #expect(result?.timespan == "1 day")
    }

    @Test func validFormatWithHourTimespan() {
        let fileName = "BTC3X_2025-01-01_2025-01-31_1_hour.parquet"
        let result = ParquetFileNameParser.parse(fileName)

        #expect(result != nil)
        #expect(result?.ticker == "BTC3X")
        #expect(result?.timespan == "1 hour")
    }

    @Test func invalidFormatReturnsFallback() {
        let fileName = "random_file.parquet"
        let result = ParquetFileNameParser.parse(fileName)

        #expect(result == nil)

        let displayName = ParquetFileNameParser.displayName(for: fileName)
        #expect(displayName == "random_file")
    }

    @Test func invalidFormatTooFewComponents() {
        let fileName = "AAPL_2024-01-01.parquet"
        let result = ParquetFileNameParser.parse(fileName)

        #expect(result == nil)
    }

    @Test func displayNameForValidFormat() {
        let fileName = "ETHUSDT_2025-04-19_2025-04-21_1_minute.parquet"
        let displayName = ParquetFileNameParser.displayName(for: fileName)

        #expect(displayName.contains("ETHUSDT"))
        #expect(displayName.contains("1 minute"))
        #expect(displayName.contains("•"))
    }

    @Test func displayNameForInvalidFormat() {
        let fileName = "some_random_name.parquet"
        let displayName = ParquetFileNameParser.displayName(for: fileName)

        #expect(displayName == "some_random_name")
    }
}
