//
//  DurationFormatterTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/28/25.
//

import Testing
@testable import ArgoTradingSwift

struct DurationFormatterTests {

    @Test func zeroSeconds() {
        let result = DurationFormatter.format(0)
        #expect(result == "0s")
    }

    @Test func secondsOnly() {
        #expect(DurationFormatter.format(1) == "1s")
        #expect(DurationFormatter.format(30) == "30s")
        #expect(DurationFormatter.format(59) == "59s")
    }

    @Test func minutesAndSeconds() {
        #expect(DurationFormatter.format(60) == "1m")
        #expect(DurationFormatter.format(61) == "1m 1s")
        #expect(DurationFormatter.format(90) == "1m 30s")
        #expect(DurationFormatter.format(3599) == "59m 59s")
    }

    @Test func hoursMinutesSeconds() {
        #expect(DurationFormatter.format(3600) == "1h")
        #expect(DurationFormatter.format(3661) == "1h 1m 1s")
        #expect(DurationFormatter.format(7200) == "2h")
        #expect(DurationFormatter.format(7322) == "2h 2m 2s")
    }

    @Test func daysHoursMinutesSeconds() {
        let oneDay = 24 * 3600.0
        #expect(DurationFormatter.format(oneDay) == "1d")
        #expect(DurationFormatter.format(oneDay + 3661) == "1d 1h 1m 1s")
        #expect(DurationFormatter.format(2 * oneDay) == "2d")
    }

    @Test func monthsDaysHoursMinutesSeconds() {
        let oneMonth = 30 * 24 * 3600.0
        #expect(DurationFormatter.format(oneMonth) == "1mo")
        #expect(DurationFormatter.format(oneMonth + 86400) == "1mo 1d")
        #expect(DurationFormatter.format(2 * oneMonth + 3661) == "2mo 1h 1m 1s")
    }

    @Test func yearsMonthsDaysHoursMinutesSeconds() {
        let oneYear = 365 * 24 * 3600.0
        #expect(DurationFormatter.format(oneYear) == "1y")
        #expect(DurationFormatter.format(oneYear + 30 * 24 * 3600) == "1y 1mo")
        #expect(DurationFormatter.format(2 * oneYear + 60 * 24 * 3600 + 86400 + 3661) == "2y 2mo 1d 1h 1m 1s")
    }

    @Test func skipsZeroComponents() {
        #expect(DurationFormatter.format(3600) == "1h")
        #expect(DurationFormatter.format(86400) == "1d")
        #expect(DurationFormatter.format(86400 + 60) == "1d 1m")
        #expect(DurationFormatter.format(86400 + 3600) == "1d 1h")
    }

    @Test func largeValues() {
        let twoYears = 2 * 365 * 24 * 3600.0
        let threeMonths = 3 * 30 * 24 * 3600.0
        let fiveDays = 5 * 24 * 3600.0
        let total = twoYears + threeMonths + fiveDays + 7200 + 180 + 45
        #expect(DurationFormatter.format(total) == "2y 3mo 5d 2h 3m 45s")
    }
}
