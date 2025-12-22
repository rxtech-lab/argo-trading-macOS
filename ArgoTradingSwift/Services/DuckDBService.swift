//
//  DuckDBService.swift
//  trading-analyzer
//
//  Created by Qiwei Li on 3/13/25.
//

import DuckDB
import Foundation
import SwiftUI
import TabularData

/// A generic structure that represents paginated results
struct PaginationResult<T> {
    /// The current page of items
    let items: [T]
    /// The total number of items across all pages
    let total: Int
    /// The current page number (1-based)
    let page: Int
    /// The number of items per page
    let pageSize: Int
    /// Whether there are more pages available
    var hasMore: Bool {
        return page * pageSize < total
    }
}

typealias FoundationDate = Foundation.Date

enum DuckDBError: LocalizedError {
    case connectionError
    case missingDataset
    case dataError(String)

    var errorDescription: String? {
        switch self {
        case .connectionError:
            return "Connection to the database is not established"
        case .missingDataset:
            return "No dataset is loaded"
        case .dataError(let message):
            return message
        }
    }
}

@Observable
class DuckDBService: DuckDBServiceProtocol {
    var database: Database?
    var connection: Connection?
    private var currentDataset: URL?

    /// Cached DateFormatter for parsing UTC date strings
    private static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    func initDatabase() throws {
        // Only initialize once - skip if already connected
        guard database == nil else { return }

        let database = try Database(store: .inMemory)
        let connection = try database.connect()

        self.database = database
        self.connection = connection
    }

    func loadDataset(filePath: URL) async throws {
        // check if file exist
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }
        currentDataset = filePath
    }

    func fetchPriceData(
        page: Int = 1,
        pageSize: Int = 20,
        sortColumn: String = "time",
        sortDirection: String = "ASC"
    ) async throws
        -> PaginationResult<PriceData>
    {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        guard let dataset = currentDataset else {
            throw DuckDBError.missingDataset
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = ["time", "open", "high", "low", "close", "volume"]
        let column = validColumns.contains(sortColumn) ? sortColumn : "time"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "ASC"

        // First get the total count
        let countQuery = """
        SELECT COUNT(*) as total
        FROM read_parquet('\(dataset.path)')
        """

        let countResult = try connection.query(countQuery)
        let totalCount = countResult[0].cast(to: Int.self)[0]

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination and sorting
        let query = """
        SELECT id, CAST(time AS VARCHAR), symbol, open, high, low, close, volume
        FROM read_parquet('\(dataset.path)')
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        for r in result {
            print(r)
        }

        let idColumn = result[0].cast(to: String.self)
        let timeColumn = result[1].cast(to: String.self)
        let symbolColumn = result[2].cast(to: String.self)
        let openColumn = result[3].cast(to: Double.self)
        let highColumn = result[4].cast(to: Double.self)
        let lowColumn = result[5].cast(to: Double.self)
        let closeColumn = result[6].cast(to: Double.self)
        let volumeColumn = result[7].cast(to: Double.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(idColumn).eraseToAnyColumn(),
            TabularData.Column(timeColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(openColumn).eraseToAnyColumn(),
            TabularData.Column(highColumn).eraseToAnyColumn(),
            TabularData.Column(lowColumn).eraseToAnyColumn(),
            TabularData.Column(closeColumn).eraseToAnyColumn(),
            TabularData.Column(volumeColumn).eraseToAnyColumn(),
        ])

        let priceData = dataFrame.rows.map { row in
            let time = row[1, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                date: utcDate,
                id: row[0, String.self] ?? "",
                ticker: row[2, String.self] ?? "",
                open: row[3, Double.self] ?? 0.0,
                high: row[4, Double.self] ?? 0.0,
                low: row[5, Double.self] ?? 0.0,
                close: row[6, Double.self] ?? 0.0,
                volume: row[7, Double.self] ?? 0.0
            )
        }

        return PaginationResult(
            items: priceData,
            total: totalCount ?? 0,
            page: page,
            pageSize: pageSize
        )
    }

    /// Get total row count for a dataset
    func getTotalCount(for filePath: URL) async throws -> Int {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        let countQuery = """
        SELECT COUNT(*) as total
        FROM read_parquet('\(filePath.path)')
        """

        let countResult = try connection.query(countQuery)
        return countResult[0].cast(to: Int.self)[0] ?? 0
    }

    /// Fetch price data by offset and count for lazy loading
    func fetchPriceDataRange(
        filePath: URL,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData] {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        let query = """
        SELECT id, CAST(time AS VARCHAR), symbol, open, high, low, close, volume
        FROM read_parquet('\(filePath.path)')
        ORDER BY time ASC
        LIMIT \(count) OFFSET \(startOffset)
        """

        let result = try connection.query(query)

        let idColumn = result[0].cast(to: String.self)
        let timeColumn = result[1].cast(to: String.self)
        let symbolColumn = result[2].cast(to: String.self)
        let openColumn = result[3].cast(to: Double.self)
        let highColumn = result[4].cast(to: Double.self)
        let lowColumn = result[5].cast(to: Double.self)
        let closeColumn = result[6].cast(to: Double.self)
        let volumeColumn = result[7].cast(to: Double.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(idColumn).eraseToAnyColumn(),
            TabularData.Column(timeColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(openColumn).eraseToAnyColumn(),
            TabularData.Column(highColumn).eraseToAnyColumn(),
            TabularData.Column(lowColumn).eraseToAnyColumn(),
            TabularData.Column(closeColumn).eraseToAnyColumn(),
            TabularData.Column(volumeColumn).eraseToAnyColumn(),
        ])

        return dataFrame.rows.map { row in
            let time = row[1, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                date: utcDate,
                id: row[0, String.self] ?? "",
                ticker: row[2, String.self] ?? "",
                open: row[3, Double.self] ?? 0.0,
                high: row[4, Double.self] ?? 0.0,
                low: row[5, Double.self] ?? 0.0,
                close: row[6, Double.self] ?? 0.0,
                volume: row[7, Double.self] ?? 0.0
            )
        }
    }

    /// Get total count of aggregated rows for a given time interval
    func getAggregatedCount(for filePath: URL, interval: ChartTimeInterval) async throws -> Int {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // For 1s interval, use existing count (no aggregation)
        if interval == .oneSecond {
            return try await getTotalCount(for: filePath)
        }

        let countQuery = """
        SELECT COUNT(*) as total
        FROM (
            SELECT date_trunc('\(interval.duckDBInterval)', time) as interval_time
            FROM read_parquet('\(filePath.path)')
            GROUP BY interval_time
        ) subquery
        """

        let countResult = try connection.query(countQuery)
        return countResult[0].cast(to: Int.self)[0] ?? 0
    }

    /// Fetch aggregated price data for a given time interval
    func fetchAggregatedPriceDataRange(
        filePath: URL,
        interval: ChartTimeInterval,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData] {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // For 1s interval, use existing method (no aggregation)
        if interval == .oneSecond {
            return try await fetchPriceDataRange(filePath: filePath, startOffset: startOffset, count: count)
        }

        // Aggregation query using DuckDB's FIRST/LAST functions
        // Note: If FIRST/LAST are not available, we use a subquery approach
        let query = """
        WITH ordered_data AS (
            SELECT
                date_trunc('\(interval.duckDBInterval)', time) as interval_time,
                symbol,
                open, high, low, close, volume,
                ROW_NUMBER() OVER (PARTITION BY date_trunc('\(interval.duckDBInterval)', time) ORDER BY time ASC) as rn_first,
                ROW_NUMBER() OVER (PARTITION BY date_trunc('\(interval.duckDBInterval)', time) ORDER BY time DESC) as rn_last
            FROM read_parquet('\(filePath.path)')
        )
        SELECT
            CAST(interval_time AS VARCHAR) as interval_time,
            symbol,
            MAX(CASE WHEN rn_first = 1 THEN open END) as open,
            MAX(high) as high,
            MIN(low) as low,
            MAX(CASE WHEN rn_last = 1 THEN close END) as close,
            SUM(volume) as volume
        FROM ordered_data
        GROUP BY interval_time, symbol
        ORDER BY interval_time ASC
        LIMIT \(count) OFFSET \(startOffset)
        """

        let result = try connection.query(query)

        let timeColumn = result[0].cast(to: String.self)
        let symbolColumn = result[1].cast(to: String.self)
        let openColumn = result[2].cast(to: Double.self)
        let highColumn = result[3].cast(to: Double.self)
        let lowColumn = result[4].cast(to: Double.self)
        let closeColumn = result[5].cast(to: Double.self)
        let volumeColumn = result[6].cast(to: Double.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(timeColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(openColumn).eraseToAnyColumn(),
            TabularData.Column(highColumn).eraseToAnyColumn(),
            TabularData.Column(lowColumn).eraseToAnyColumn(),
            TabularData.Column(closeColumn).eraseToAnyColumn(),
            TabularData.Column(volumeColumn).eraseToAnyColumn(),
        ])

        return dataFrame.rows.enumerated().map { (index, row) in
            let time = row[0, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                date: utcDate,
                id: "agg-\(startOffset + index)",  // Generate unique ID for aggregated rows
                ticker: row[1, String.self] ?? "",
                open: row[2, Double.self] ?? 0.0,
                high: row[3, Double.self] ?? 0.0,
                low: row[4, Double.self] ?? 0.0,
                close: row[5, Double.self] ?? 0.0,
                volume: row[6, Double.self] ?? 0.0
            )
        }
    }
}
