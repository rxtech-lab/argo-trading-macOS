//
//  DuckDBServiceTimestampTests.swift
//  ArgoTradingSwiftTests
//

import Foundation
import Testing
@testable import ArgoTradingSwift

struct DuckDBServiceTimestampTests {
    @Test func parsesISO8601FractionalTimestampFromLiveLogs() {
        let date = DuckDBService.parseTimestamp("2026-06-20T06:27:00.000Z")

        #expect(components(for: date).year == 2026)
        #expect(components(for: date).month == 6)
        #expect(components(for: date).day == 20)
        #expect(components(for: date).hour == 6)
        #expect(components(for: date).minute == 27)
        #expect(components(for: date).second == 0)
    }

    @Test func parsesDuckDBSpaceSeparatedTimestamp() {
        let date = DuckDBService.parseTimestamp("2026-06-20 06:28:00")

        #expect(components(for: date).year == 2026)
        #expect(components(for: date).month == 6)
        #expect(components(for: date).day == 20)
        #expect(components(for: date).hour == 6)
        #expect(components(for: date).minute == 28)
        #expect(components(for: date).second == 0)
    }

    @Test func invalidTimestampDoesNotFallBackToCurrentTime() {
        let date = DuckDBService.parseTimestamp("not a timestamp")

        #expect(date == Date(timeIntervalSince1970: 0))
    }

    private func components(for date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
}
