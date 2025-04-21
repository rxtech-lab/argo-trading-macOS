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
class DuckDBService {
    var database: Database?
    var connection: Connection?
    private var currentDataset: URL?

    func initDatabase() throws {
        // Create our database and connection as described above
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

    @MainActor
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

            // Create a date formatter for parsing the input time
            let inputFormatter = DateFormatter()
            inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Adjust this to match your input format
            inputFormatter.timeZone = TimeZone(identifier: "UTC") // Assuming original time is in UTC

            // Parse the date in the original timezone
            let utcDate = inputFormatter.date(from: time ?? "") ?? Date()

            // Convert to user's local timezone
            let localDate = utcDate // The Date object remains the same, but will display in local time when formatted

            return PriceData(
                date: localDate, id: row[0, String.self] ?? "", ticker: row[2, String.self] ?? "", open: row[3, Double.self] ?? 0.0,
                high: row[4, Double.self] ?? 0.0, low: row[5, Double.self] ?? 0.0,
                close: row[6, Double.self] ?? 0.0, volume: row[7, Double.self] ?? 0.0
            )
        }

        return PaginationResult(
            items: priceData,
            total: totalCount ?? 0,
            page: page,
            pageSize: pageSize
        )
    }
}
