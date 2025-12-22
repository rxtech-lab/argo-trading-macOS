//
//  DuckDBServiceProtocol.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation

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
}
