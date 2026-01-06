//
//  DuckDBServiceProtocol.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation
import LightweightChart

/// Protocol for database operations used by PriceChartViewModel
/// Enables dependency injection and mocking for tests
protocol DuckDBServiceProtocol {
    /// Initialize the database connection
    func initDatabase() throws

    /// Get the total number of rows in a parquet file
    func getTotalCount(for filePath: URL) async throws -> Int

    /// Fetch a range of price data from a parquet file
    func fetchPriceDataRange(
        filePath: URL,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData]

    /// Get total count of aggregated rows for a given time interval
    func getAggregatedCount(for filePath: URL, interval: ChartTimeInterval) async throws -> Int

    /// Fetch aggregated price data for a given time interval
    func fetchAggregatedPriceDataRange(
        filePath: URL,
        interval: ChartTimeInterval,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData]

    /// Get the row offset (0-based) for a given timestamp
    /// Returns the offset where this timestamp would appear in the sorted data
    func getOffsetForTimestamp(
        filePath: URL,
        timestamp: Date,
        interval: ChartTimeInterval
    ) async throws -> Int

    /// Fetch trades within a time range
    func fetchTrades(
        filePath: URL,
        startTime: Date,
        endTime: Date
    ) async throws -> [Trade]

    /// Fetch marks within a time range
    func fetchMarks(
        filePath: URL,
        startTime: Date,
        endTime: Date
    ) async throws -> [Mark]
}
