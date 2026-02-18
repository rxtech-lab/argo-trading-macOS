//
//  LiveChartDataAggregator.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation
import LightweightChart

/// Pure-function utility that aggregates `[PriceData]` into larger time-interval buckets.
enum LiveChartDataAggregator {
    /// Aggregates candles by grouping into buckets of `intervalSeconds`.
    ///
    /// Each bucket uses the floored epoch as its timestamp, producing OHLCV:
    /// first open, max high, min low, last close, sum volume.
    /// The returned array has sequential `globalIndex` values starting from 0.
    static func aggregate(_ data: [PriceData], intervalSeconds: Int) -> [PriceData] {
        guard !data.isEmpty, intervalSeconds > 0 else { return [] }

        let interval = Double(intervalSeconds)

        // Group candles by bucket key (floored epoch)
        var buckets: [(key: Double, candles: [PriceData])] = []
        var currentKey: Double?
        var currentCandles: [PriceData] = []

        for candle in data {
            let epoch = candle.date.timeIntervalSince1970
            let bucketKey = (epoch / interval).rounded(.down) * interval

            if bucketKey == currentKey {
                currentCandles.append(candle)
            } else {
                if let key = currentKey {
                    buckets.append((key: key, candles: currentCandles))
                }
                currentKey = bucketKey
                currentCandles = [candle]
            }
        }
        // Flush last bucket
        if let key = currentKey {
            buckets.append((key: key, candles: currentCandles))
        }

        // Build aggregated PriceData array
        return buckets.enumerated().map { index, bucket in
            let candles = bucket.candles
            return PriceData(
                globalIndex: index,
                date: Date(timeIntervalSince1970: bucket.key),
                ticker: candles[0].ticker,
                open: candles[0].open,
                high: candles.map(\.high).max()!,
                low: candles.map(\.low).min()!,
                close: candles[candles.count - 1].close,
                volume: candles.reduce(0) { $0 + $1.volume }
            )
        }
    }
}
