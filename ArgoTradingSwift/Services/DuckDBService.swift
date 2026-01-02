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

        let priceData = dataFrame.rows.enumerated().map { (index, row) in
            let time = row[1, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                globalIndex: offset + index,
                date: utcDate,
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

        return dataFrame.rows.enumerated().map { (index, row) in
            let time = row[1, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                globalIndex: startOffset + index,
                date: utcDate,
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

        // Build time bucket expression based on whether this is a standard or non-standard interval
        let timeBucketExpr = Self.timeBucketExpression(for: interval)

        let countQuery = """
        SELECT COUNT(*) as total
        FROM (
            SELECT \(timeBucketExpr) as interval_time
            FROM read_parquet('\(filePath.path)')
            GROUP BY interval_time
        ) subquery
        """

        let countResult = try connection.query(countQuery)
        return countResult[0].cast(to: Int.self)[0] ?? 0
    }

    /// Build a time bucket expression for the given interval
    /// For standard intervals (1m, 1h, 1d), uses date_trunc
    /// For non-standard intervals (3m, 5m, 15m, 30m, etc.), uses epoch-based bucketing
    private static func timeBucketExpression(for interval: ChartTimeInterval) -> String {
        if interval.aggregationMultiplier == nil {
            // Standard interval - use date_trunc
            return "date_trunc('\(interval.duckDBInterval)', time)"
        } else {
            // Non-standard interval - use epoch-based bucketing
            return """
            TIMESTAMP '1970-01-01' + INTERVAL (FLOOR(EXTRACT(EPOCH FROM time) / \(interval.seconds)) * \(interval.seconds)) SECOND
            """
        }
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

        // Build time bucket expression based on whether this is a standard or non-standard interval
        let timeBucketExpr = Self.timeBucketExpression(for: interval)

        // Aggregation query using DuckDB's FIRST/LAST functions
        // Note: If FIRST/LAST are not available, we use a subquery approach
        let query = """
        WITH ordered_data AS (
            SELECT
                \(timeBucketExpr) as interval_time,
                symbol,
                open, high, low, close, volume,
                ROW_NUMBER() OVER (PARTITION BY \(timeBucketExpr) ORDER BY time ASC) as rn_first,
                ROW_NUMBER() OVER (PARTITION BY \(timeBucketExpr) ORDER BY time DESC) as rn_last
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

        return dataFrame.rows.enumerated().map { index, row in
            let time = row[0, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? Date()

            return PriceData(
                globalIndex: startOffset + index,
                date: utcDate,
                ticker: row[1, String.self] ?? "",
                open: row[2, Double.self] ?? 0.0,
                high: row[3, Double.self] ?? 0.0,
                low: row[4, Double.self] ?? 0.0,
                close: row[5, Double.self] ?? 0.0,
                volume: row[6, Double.self] ?? 0.0
            )
        }
    }

    /// Get the row offset (0-based) for a given timestamp
    /// Returns the offset where this timestamp would appear in the sorted data
    func getOffsetForTimestamp(
        filePath: URL,
        timestamp: FoundationDate,
        interval: ChartTimeInterval
    ) async throws -> Int {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        let timestampStr = Self.utcDateFormatter.string(from: timestamp)

        if interval == .oneSecond {
            // For 1s interval, count rows before this timestamp
            let query = """
            SELECT COUNT(*) as offset_count
            FROM read_parquet('\(filePath.path)')
            WHERE time <= '\(timestampStr)'
            """
            let result = try connection.query(query)
            return max(0, (result[0].cast(to: Int.self)[0] ?? 1) - 1)
        } else {
            // For aggregated intervals, use time bucket
            let timeBucketExpr = Self.timeBucketExpression(for: interval)
            let query = """
            WITH aggregated AS (
                SELECT DISTINCT \(timeBucketExpr) as interval_time
                FROM read_parquet('\(filePath.path)')
            )
            SELECT COUNT(*) as offset_count
            FROM aggregated
            WHERE interval_time <= '\(timestampStr)'
            """
            let result = try connection.query(query)
            return max(0, (result[0].cast(to: Int.self)[0] ?? 1) - 1)
        }
    }

    /// Fetch trade data from a parquet file with pagination
    func fetchTradeData(
        filePath: URL,
        page: Int = 1,
        pageSize: Int = 100,
        sortColumn: String = "timestamp",
        sortDirection: String = "DESC"
    ) async throws -> PaginationResult<Trade> {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = [
            "order_id", "symbol", "order_type", "quantity", "price",
            "timestamp", "is_completed", "reason", "message",
            "strategy_name", "executed_at", "executed_qty", "executed_price",
            "commission", "pnl", "position_type",
        ]
        let column = validColumns.contains(sortColumn) ? sortColumn : "timestamp"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "DESC"

        // First get the total count
        let countQuery = """
        SELECT COUNT(*) as total
        FROM read_parquet('\(filePath.path)')
        """

        let countResult = try connection.query(countQuery)
        let totalCount = countResult[0].cast(to: Int.self)[0]

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination and sorting
        let query = """
        SELECT
            order_id,
            symbol,
            order_type,
            quantity,
            price,
            CAST(timestamp AS VARCHAR),
            is_completed,
            reason,
            message,
            strategy_name,
            CAST(executed_at AS VARCHAR),
            executed_qty,
            executed_price,
            commission,
            pnl,
            position_type
        FROM read_parquet('\(filePath.path)')
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let orderIdColumn = result[0].cast(to: String.self)
        let symbolColumn = result[1].cast(to: String.self)
        let orderTypeColumn = result[2].cast(to: String.self)
        let quantityColumn = result[3].cast(to: Double.self)
        let priceColumn = result[4].cast(to: Double.self)
        let timestampColumn = result[5].cast(to: String.self)
        let isCompletedColumn = result[6].cast(to: Bool.self)
        let reasonColumn = result[7].cast(to: String.self)
        let messageColumn = result[8].cast(to: String.self)
        let strategyNameColumn = result[9].cast(to: String.self)
        let executedAtColumn = result[10].cast(to: String.self)
        let executedQtyColumn = result[11].cast(to: Double.self)
        let executedPriceColumn = result[12].cast(to: Double.self)
        let commissionColumn = result[13].cast(to: Double.self)
        let pnlColumn = result[14].cast(to: Double.self)
        let positionTypeColumn = result[15].cast(to: String.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(orderIdColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(orderTypeColumn).eraseToAnyColumn(),
            TabularData.Column(quantityColumn).eraseToAnyColumn(),
            TabularData.Column(priceColumn).eraseToAnyColumn(),
            TabularData.Column(timestampColumn).eraseToAnyColumn(),
            TabularData.Column(isCompletedColumn).eraseToAnyColumn(),
            TabularData.Column(reasonColumn).eraseToAnyColumn(),
            TabularData.Column(messageColumn).eraseToAnyColumn(),
            TabularData.Column(strategyNameColumn).eraseToAnyColumn(),
            TabularData.Column(executedAtColumn).eraseToAnyColumn(),
            TabularData.Column(executedQtyColumn).eraseToAnyColumn(),
            TabularData.Column(executedPriceColumn).eraseToAnyColumn(),
            TabularData.Column(commissionColumn).eraseToAnyColumn(),
            TabularData.Column(pnlColumn).eraseToAnyColumn(),
            TabularData.Column(positionTypeColumn).eraseToAnyColumn(),
        ])

        let trades = dataFrame.rows.map { row in
            let timestampStr = row[5, String.self]
            let timestamp = Self.utcDateFormatter.date(from: timestampStr ?? "") ?? Date()

            let executedAtStr = row[10, String.self]
            let executedAt = executedAtStr.flatMap { Self.utcDateFormatter.date(from: $0) }
            let orderSide = row[2, String.self] ?? ""

            return Trade(
                orderId: row[0, String.self] ?? "",
                symbol: row[1, String.self] ?? "",
                side: OrderSide(rawValue: orderSide) ?? .buy,
                quantity: row[3, Double.self] ?? 0.0,
                price: row[4, Double.self] ?? 0.0,
                timestamp: timestamp,
                isCompleted: row[6, Bool.self] ?? false,
                reason: row[7, String.self] ?? "",
                message: row[8, String.self] ?? "",
                strategyName: row[9, String.self] ?? "",
                executedAt: executedAt,
                executedQty: row[11, Double.self] ?? 0.0,
                executedPrice: row[12, Double.self] ?? 0.0,
                commission: row[13, Double.self] ?? 0.0,
                pnl: row[14, Double.self] ?? 0.0,
                positionType: row[15, String.self] ?? ""
            )
        }

        return PaginationResult(
            items: trades,
            total: totalCount ?? 0,
            page: page,
            pageSize: pageSize
        )
    }

    /// Fetch order data from a parquet file with pagination
    func fetchOrderData(
        filePath: URL,
        page: Int = 1,
        pageSize: Int = 100,
        sortColumn: String = "timestamp",
        sortDirection: String = "DESC"
    ) async throws -> PaginationResult<Order> {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = [
            "order_id", "symbol", "order_type", "quantity", "price",
            "timestamp", "is_completed", "reason", "message",
            "strategy_name", "position_type",
        ]
        let column = validColumns.contains(sortColumn) ? sortColumn : "timestamp"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "DESC"

        // First get the total count
        let countQuery = """
        SELECT COUNT(*) as total
        FROM read_parquet('\(filePath.path)')
        """

        let countResult = try connection.query(countQuery)
        let totalCount = countResult[0].cast(to: Int.self)[0]

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination and sorting
        let query = """
        SELECT
            order_id,
            symbol,
            order_type,
            quantity,
            price,
            CAST(timestamp AS VARCHAR),
            is_completed,
            reason,
            message,
            strategy_name,
            position_type,
            status,
        FROM read_parquet('\(filePath.path)')
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let orderIdColumn = result[0].cast(to: String.self)
        let symbolColumn = result[1].cast(to: String.self)
        let orderTypeColumn = result[2].cast(to: String.self)
        let quantityColumn = result[3].cast(to: Double.self)
        let priceColumn = result[4].cast(to: Double.self)
        let timestampColumn = result[5].cast(to: String.self)
        let isCompletedColumn = result[6].cast(to: Bool.self)
        let reasonColumn = result[7].cast(to: String.self)
        let messageColumn = result[8].cast(to: String.self)
        let strategyNameColumn = result[9].cast(to: String.self)
        let positionTypeColumn = result[10].cast(to: String.self)
        let statusColumn = result[11].cast(to: String.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(orderIdColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(orderTypeColumn).eraseToAnyColumn(),
            TabularData.Column(quantityColumn).eraseToAnyColumn(),
            TabularData.Column(priceColumn).eraseToAnyColumn(),
            TabularData.Column(timestampColumn).eraseToAnyColumn(),
            TabularData.Column(isCompletedColumn).eraseToAnyColumn(),
            TabularData.Column(reasonColumn).eraseToAnyColumn(),
            TabularData.Column(messageColumn).eraseToAnyColumn(),
            TabularData.Column(strategyNameColumn).eraseToAnyColumn(),
            TabularData.Column(positionTypeColumn).eraseToAnyColumn(),
            TabularData.Column(statusColumn).eraseToAnyColumn(),
        ])

        let orders = dataFrame.rows.map { row in
            let timestampStr = row[5, String.self]
            let timestamp = Self.utcDateFormatter.date(from: timestampStr ?? "") ?? Date()
            let orderStatisStr = row[11, String.self] ?? ""

            return Order(
                orderId: row[0, String.self] ?? "",
                symbol: row[1, String.self] ?? "",
                orderType: row[2, String.self] ?? "",
                quantity: row[3, Double.self] ?? 0.0,
                price: row[4, Double.self] ?? 0.0,
                timestamp: timestamp,
                isCompleted: row[6, Bool.self] ?? false,
                reason: row[7, String.self] ?? "",
                message: row[8, String.self] ?? "",
                strategyName: row[9, String.self] ?? "",
                positionType: row[10, String.self] ?? "",
                // fallback to .filled if status is unrecognized since it is the default status
                status: OrderStatus(rawValue: orderStatisStr) ?? .filled
            )
        }

        return PaginationResult(
            items: orders,
            total: totalCount ?? 0,
            page: page,
            pageSize: pageSize
        )
    }

    /// Fetch mark data from a parquet file with pagination
    func fetchMarkData(
        filePath: URL,
        page: Int = 1,
        pageSize: Int = 100,
        sortColumn: String = "id",
        sortDirection: String = "ASC"
    ) async throws -> PaginationResult<Mark> {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = [
            "id", "market_data_id", "signal_type", "signal_name", "signal_time",
            "signal_symbol", "color", "shape", "title", "message", "category",
        ]
        let column = validColumns.contains(sortColumn) ? sortColumn : "id"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "ASC"

        // First get the total count
        let countQuery = """
        SELECT COUNT(*) as total
        FROM read_parquet('\(filePath.path)')
        """

        let countResult = try connection.query(countQuery)
        let totalCount = countResult[0].cast(to: Int.self)[0]

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination and sorting
        let query = """
        SELECT
            id,
            market_data_id,
            signal_type,
            signal_name,
            CAST(signal_time AS VARCHAR),
            signal_symbol,
            color,
            shape,
            title,
            message,
            category
        FROM read_parquet('\(filePath.path)')
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let idColumn = result[0].cast(to: Int64.self)
        let marketDataIdColumn = result[1].cast(to: String.self)
        let signalTypeColumn = result[2].cast(to: String.self)
        let signalNameColumn = result[3].cast(to: String.self)
        let signalTimeColumn = result[4].cast(to: String.self)
        let signalSymbolColumn = result[5].cast(to: String.self)
        let colorColumn = result[6].cast(to: String.self)
        let shapeColumn = result[7].cast(to: String.self)
        let titleColumn = result[8].cast(to: String.self)
        let messageColumn = result[9].cast(to: String.self)
        let categoryColumn = result[10].cast(to: String.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(idColumn).eraseToAnyColumn(),
            TabularData.Column(marketDataIdColumn).eraseToAnyColumn(),
            TabularData.Column(signalTypeColumn).eraseToAnyColumn(),
            TabularData.Column(signalNameColumn).eraseToAnyColumn(),
            TabularData.Column(signalTimeColumn).eraseToAnyColumn(),
            TabularData.Column(signalSymbolColumn).eraseToAnyColumn(),
            TabularData.Column(colorColumn).eraseToAnyColumn(),
            TabularData.Column(shapeColumn).eraseToAnyColumn(),
            TabularData.Column(titleColumn).eraseToAnyColumn(),
            TabularData.Column(messageColumn).eraseToAnyColumn(),
            TabularData.Column(categoryColumn).eraseToAnyColumn(),
        ])

        // ISO8601 date formatter for signal_time
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let marks = dataFrame.rows.compactMap { row -> Mark? in
            let shapeStr = row[7, String.self] ?? "circle"
            let shape = MarkShape(rawValue: shapeStr) ?? .circle

            // Parse signal time separately (always available in parquet)
            let signalTypeStr = row[2, String.self] ?? ""
            let signalNameStr = row[3, String.self] ?? ""
            let signalTimeStr = row[4, String.self] ?? ""
            let signalSymbolStr = row[5, String.self] ?? ""
            let signalTime = Self.utcDateFormatter.date(from: signalTimeStr) ?? Date()
            let signalType = SignalType(rawValue: signalTypeStr) ?? .noAction

            let signal = Signal(time: signalTime, type: signalType, name: signalNameStr, reason: "", rawValue: "", symbol: signalSymbolStr, indicator: "")
            let markColorStr = row[6, String.self] ?? "#FFFFFF"
            let markColor = MarkColor(string: markColorStr)

            return Mark(
                marketDataId: row[1, String.self] ?? "",
                color: markColor,
                shape: shape,
                title: row[8, String.self] ?? "",
                message: row[9, String.self] ?? "",
                category: row[10, String.self] ?? "",
                signal: signal
            )
        }

        return PaginationResult(
            items: marks,
            total: totalCount ?? 0,
            page: page,
            pageSize: pageSize
        )
    }

    /// Fetch price data centered around a specific timestamp
    /// Returns approximately `count` rows with the target timestamp in the middle
    func fetchPriceDataAroundTimestamp(
        filePath: URL,
        timestamp: FoundationDate,
        count: Int = 100
    ) async throws -> [PriceData] {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        // Format timestamp for SQL query
        let timestampStr = Self.utcDateFormatter.string(from: timestamp)

        // Find the row number where the timestamp falls
        let findRowQuery = """
        WITH numbered AS (
            SELECT ROW_NUMBER() OVER (ORDER BY time ASC) as rn
            FROM read_parquet('\(filePath.path)')
            WHERE time <= '\(timestampStr)'
        )
        SELECT COALESCE(MAX(rn), 1) as target_row FROM numbered
        """

        let rowResult = try connection.query(findRowQuery)
        let targetRow = rowResult[0].cast(to: Int.self)[0] ?? 1

        // Calculate offset to center the data around the target row
        let halfCount = count / 2
        let startOffset = max(0, targetRow - halfCount - 1)

        // Fetch the surrounding data
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

        return dataFrame.rows.enumerated().map { (index, row) in
            let time = row[1, String.self]
            let utcDate = Self.utcDateFormatter.date(from: time ?? "") ?? FoundationDate()

            return PriceData(
                globalIndex: startOffset + index,
                date: utcDate,
                ticker: row[2, String.self] ?? "",
                open: row[3, Double.self] ?? 0.0,
                high: row[4, Double.self] ?? 0.0,
                low: row[5, Double.self] ?? 0.0,
                close: row[6, Double.self] ?? 0.0,
                volume: row[7, Double.self] ?? 0.0
            )
        }
    }

    /// Fetch trades within a time range for chart overlay
    func fetchTrades(
        filePath: URL,
        startTime: FoundationDate,
        endTime: FoundationDate
    ) async throws -> [Trade] {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        let startTimeStr = Self.utcDateFormatter.string(from: startTime)
        let endTimeStr = Self.utcDateFormatter.string(from: endTime)

        // Fetch trades within time range ordered by timestamp
        let query = """
        SELECT
            order_id,
            symbol,
            order_type,
            quantity,
            price,
            CAST(timestamp AS VARCHAR),
            is_completed,
            reason,
            message,
            strategy_name,
            CAST(executed_at AS VARCHAR),
            executed_qty,
            executed_price,
            commission,
            pnl,
            position_type
        FROM read_parquet('\(filePath.path)')
        WHERE timestamp >= '\(startTimeStr)' AND timestamp <= '\(endTimeStr)'
        ORDER BY timestamp ASC
        """

        let result = try connection.query(query)

        let orderIdColumn = result[0].cast(to: String.self)
        let symbolColumn = result[1].cast(to: String.self)
        let orderTypeColumn = result[2].cast(to: String.self)
        let quantityColumn = result[3].cast(to: Double.self)
        let priceColumn = result[4].cast(to: Double.self)
        let timestampColumn = result[5].cast(to: String.self)
        let isCompletedColumn = result[6].cast(to: Bool.self)
        let reasonColumn = result[7].cast(to: String.self)
        let messageColumn = result[8].cast(to: String.self)
        let strategyNameColumn = result[9].cast(to: String.self)
        let executedAtColumn = result[10].cast(to: String.self)
        let executedQtyColumn = result[11].cast(to: Double.self)
        let executedPriceColumn = result[12].cast(to: Double.self)
        let commissionColumn = result[13].cast(to: Double.self)
        let pnlColumn = result[14].cast(to: Double.self)
        let positionTypeColumn = result[15].cast(to: String.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(orderIdColumn).eraseToAnyColumn(),
            TabularData.Column(symbolColumn).eraseToAnyColumn(),
            TabularData.Column(orderTypeColumn).eraseToAnyColumn(),
            TabularData.Column(quantityColumn).eraseToAnyColumn(),
            TabularData.Column(priceColumn).eraseToAnyColumn(),
            TabularData.Column(timestampColumn).eraseToAnyColumn(),
            TabularData.Column(isCompletedColumn).eraseToAnyColumn(),
            TabularData.Column(reasonColumn).eraseToAnyColumn(),
            TabularData.Column(messageColumn).eraseToAnyColumn(),
            TabularData.Column(strategyNameColumn).eraseToAnyColumn(),
            TabularData.Column(executedAtColumn).eraseToAnyColumn(),
            TabularData.Column(executedQtyColumn).eraseToAnyColumn(),
            TabularData.Column(executedPriceColumn).eraseToAnyColumn(),
            TabularData.Column(commissionColumn).eraseToAnyColumn(),
            TabularData.Column(pnlColumn).eraseToAnyColumn(),
            TabularData.Column(positionTypeColumn).eraseToAnyColumn(),
        ])

        return dataFrame.rows.map { row in
            let timestampStr = row[5, String.self]
            let timestamp = Self.utcDateFormatter.date(from: timestampStr ?? "") ?? Date()

            let executedAtStr = row[10, String.self]
            let executedAt = executedAtStr.flatMap { Self.utcDateFormatter.date(from: $0) }

            let orderSide = row[2, String.self]

            return Trade(
                orderId: row[0, String.self] ?? "",
                symbol: row[1, String.self] ?? "",
                side: OrderSide(rawValue: orderSide ?? "") ?? .buy,
                quantity: row[3, Double.self] ?? 0.0,
                price: row[4, Double.self] ?? 0.0,
                timestamp: timestamp,
                isCompleted: row[6, Bool.self] ?? false,
                reason: row[7, String.self] ?? "",
                message: row[8, String.self] ?? "",
                strategyName: row[9, String.self] ?? "",
                executedAt: executedAt,
                executedQty: row[11, Double.self] ?? 0.0,
                executedPrice: row[12, Double.self] ?? 0.0,
                commission: row[13, Double.self] ?? 0.0,
                pnl: row[14, Double.self] ?? 0.0,
                positionType: row[15, String.self] ?? ""
            )
        }
    }

    /// Fetch marks within a time range for chart overlay
    func fetchMarks(
        filePath: URL,
        startTime: FoundationDate,
        endTime: FoundationDate
    ) async throws -> [Mark] {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Check if file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        // ISO8601 date formatter for signal_time (format: 2022-12-31T15:30:00.000Z)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startTimeStr = iso8601Formatter.string(from: startTime)
        let endTimeStr = iso8601Formatter.string(from: endTime)

        // Query marks within time range
        let query = """
        SELECT
            id,
            market_data_id,
            signal_type,
            signal_name,
            CAST(signal_time AS VARCHAR),
            signal_symbol,
            color,
            shape,
            title,
            message,
            category
        FROM read_parquet('\(filePath.path)')
        WHERE signal_time >= '\(startTimeStr)' AND signal_time <= '\(endTimeStr)'
        ORDER BY signal_time ASC
        """

        let result = try connection.query(query)

        let idColumn = result[0].cast(to: Int64.self)
        let marketDataIdColumn = result[1].cast(to: String.self)
        let signalTypeColumn = result[2].cast(to: String.self)
        let signalNameColumn = result[3].cast(to: String.self)
        let signalTimeColumn = result[4].cast(to: String.self)
        let signalSymbolColumn = result[5].cast(to: String.self)
        let colorColumn = result[6].cast(to: String.self)
        let shapeColumn = result[7].cast(to: String.self)
        let titleColumn = result[8].cast(to: String.self)
        let messageColumn = result[9].cast(to: String.self)
        let categoryColumn = result[10].cast(to: String.self)

        let dataFrame = DataFrame(columns: [
            TabularData.Column(idColumn).eraseToAnyColumn(),
            TabularData.Column(marketDataIdColumn).eraseToAnyColumn(),
            TabularData.Column(signalTypeColumn).eraseToAnyColumn(),
            TabularData.Column(signalNameColumn).eraseToAnyColumn(),
            TabularData.Column(signalTimeColumn).eraseToAnyColumn(),
            TabularData.Column(signalSymbolColumn).eraseToAnyColumn(),
            TabularData.Column(colorColumn).eraseToAnyColumn(),
            TabularData.Column(shapeColumn).eraseToAnyColumn(),
            TabularData.Column(titleColumn).eraseToAnyColumn(),
            TabularData.Column(messageColumn).eraseToAnyColumn(),
            TabularData.Column(categoryColumn).eraseToAnyColumn(),
        ])

        return dataFrame.rows.compactMap { row in
            let shapeStr = row[7, String.self] ?? "circle"
            let shape = MarkShape(rawValue: shapeStr) ?? .circle

            // Parse signal time separately (always available in parquet)
            let signalTypeStr = row[2, String.self] ?? ""
            let signalNameStr = row[3, String.self] ?? ""
            let signalTimeStr = row[4, String.self] ?? ""
            let signalSymbolStr = row[5, String.self] ?? ""
            let signalTime = Self.utcDateFormatter.date(from: signalTimeStr) ?? Date()
            let signalType = SignalType(rawValue: signalTypeStr) ?? .noAction

            let signal = Signal(time: signalTime, type: signalType, name: signalNameStr, reason: "", rawValue: "", symbol: signalSymbolStr, indicator: "")
            let markColorStr = row[6, String.self] ?? "#FFFFFF"
            let markColor = MarkColor(string: markColorStr)

            return Mark(
                marketDataId: row[1, String.self] ?? "",
                color: markColor,
                shape: shape,
                title: row[8, String.self] ?? "",
                message: row[9, String.self] ?? "",
                category: row[10, String.self] ?? "",
                signal: signal
            )
        }
    }
}
