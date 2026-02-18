//
//  LiveChartDataAggregatorTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 2/18/26.
//

import Foundation
import LightweightChart
import Testing

@testable import ArgoTradingSwift

struct LiveChartDataAggregatorTests {
    private func makeCandle(index: Int, epochSeconds: Double, open: Double, high: Double, low: Double, close: Double, volume: Double = 1.0) -> PriceData {
        PriceData(
            globalIndex: index,
            date: Date(timeIntervalSince1970: epochSeconds),
            ticker: "TEST",
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )
    }

    @Test func emptyInput() {
        let result = LiveChartDataAggregator.aggregate([], intervalSeconds: 60)
        #expect(result.isEmpty)
    }

    @Test func zeroInterval() {
        let data = [makeCandle(index: 0, epochSeconds: 100, open: 1, high: 2, low: 0.5, close: 1.5)]
        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 0)
        #expect(result.isEmpty)
    }

    @Test func noOpAggregation() {
        // Each candle is already 60s apart and interval is 60s — no merging needed
        let data = [
            makeCandle(index: 0, epochSeconds: 0, open: 10, high: 12, low: 9, close: 11, volume: 100),
            makeCandle(index: 1, epochSeconds: 60, open: 11, high: 13, low: 10, close: 12, volume: 200),
            makeCandle(index: 2, epochSeconds: 120, open: 12, high: 14, low: 11, close: 13, volume: 150),
        ]
        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result.count == 3)
        // Each bucket should have exactly one candle, preserving OHLCV
        #expect(result[0].open == 10)
        #expect(result[0].close == 11)
        #expect(result[1].open == 11)
        #expect(result[2].close == 13)
    }

    @Test func oneSecondToOneMinute() {
        // 120 one-second candles → should produce 2 one-minute buckets
        var data: [PriceData] = []
        for i in 0..<120 {
            let price = Double(100 + (i % 10))
            data.append(makeCandle(
                index: i,
                epochSeconds: Double(i),
                open: price,
                high: price + 5,
                low: price - 3,
                close: price + 1,
                volume: 10
            ))
        }

        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result.count == 2)

        // First bucket: epochs 0-59
        #expect(result[0].open == 100)  // first candle's open
        #expect(result[0].volume == 600)  // 60 candles × 10

        // Second bucket: epochs 60-119
        #expect(result[1].open == 100)  // (60 % 10) = 0 → 100
        #expect(result[1].volume == 600)
    }

    @Test func ohlcvCorrectness() {
        // 3 candles in the same 60s bucket with varying OHLCV
        let data = [
            makeCandle(index: 0, epochSeconds: 0, open: 10, high: 15, low: 8, close: 12, volume: 100),
            makeCandle(index: 1, epochSeconds: 1, open: 12, high: 20, low: 9, close: 14, volume: 200),
            makeCandle(index: 2, epochSeconds: 2, open: 14, high: 18, low: 7, close: 16, volume: 300),
        ]
        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result.count == 1)

        let bucket = result[0]
        #expect(bucket.open == 10)     // first open
        #expect(bucket.high == 20)     // max high
        #expect(bucket.low == 7)       // min low
        #expect(bucket.close == 16)    // last close
        #expect(bucket.volume == 600)  // sum volume
    }

    @Test func partialBuckets() {
        // 90 seconds of data at 1s → 60s interval should give 2 buckets (60 + 30)
        var data: [PriceData] = []
        for i in 0..<90 {
            data.append(makeCandle(
                index: i,
                epochSeconds: Double(i),
                open: 100,
                high: 101,
                low: 99,
                close: 100,
                volume: 1
            ))
        }

        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result.count == 2)
        #expect(result[0].volume == 60)  // full bucket
        #expect(result[1].volume == 30)  // partial bucket
    }

    @Test func sequentialGlobalIndex() {
        var data: [PriceData] = []
        for i in 0..<300 {
            data.append(makeCandle(
                index: i,
                epochSeconds: Double(i),
                open: 100,
                high: 101,
                low: 99,
                close: 100,
                volume: 1
            ))
        }

        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result.count == 5)
        for (i, candle) in result.enumerated() {
            #expect(candle.globalIndex == i)
        }
    }

    @Test func tickerPreserved() {
        let data = [
            PriceData(globalIndex: 0, date: Date(timeIntervalSince1970: 0), ticker: "AAPL", open: 10, high: 12, low: 9, close: 11, volume: 100),
            PriceData(globalIndex: 1, date: Date(timeIntervalSince1970: 1), ticker: "AAPL", open: 11, high: 13, low: 10, close: 12, volume: 200),
        ]
        let result = LiveChartDataAggregator.aggregate(data, intervalSeconds: 60)
        #expect(result[0].ticker == "AAPL")
    }
}
