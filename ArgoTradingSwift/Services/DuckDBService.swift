//
//  DuckDBService.swift
//  trading-analyzer
//
//  Created by Qiwei Li on 3/13/25.
//

import DuckDB
import Foundation
import LightweightChart
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

private struct CachedTable {
    let filePath: URL
    let mtime: FoundationDate
    let rowCount: Int
}

private struct CachedCount {
    let mtime: FoundationDate
    let count: Int
}

@Observable
class DuckDBService: DuckDBServiceProtocol {
    var database: Database?
    var connection: Connection?

    /// Cache of materialized in-memory tables keyed by DuckDB table name.
    /// Invalidated when the source file's path or modification time changes.
    private var cachedTables: [String: CachedTable] = [:]

    /// Cache of COUNT(*) results for parquet files queried via read_parquet.
    /// Key is `filePath.path`, optionally suffixed with a qualifier (e.g. aggregation interval).
    private var parquetCountCache: [String: CachedCount] = [:]

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

        // Parallelize scans across available cores. DuckDB's default may underuse the CPU.
        let threadCount = max(1, ProcessInfo.processInfo.activeProcessorCount)
        _ = try? connection.query("PRAGMA threads=\(threadCount)")

        self.database = database
        self.connection = connection
    }

    /// Returns the modification time of a file, or nil if the file doesn't exist.
    private static func fileMTime(path: String) -> FoundationDate? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.modificationDate] as? FoundationDate
    }

    /// Materialize a parquet file into a named in-memory DuckDB table.
    /// Skips work if the same file (same path + mtime) is already cached.
    /// Returns the cached row count. Throws `.missingDataset` if the file doesn't exist.
    @discardableResult
    private func materializeTableIfNeeded(
        tableName: String,
        filePath: URL,
        projection: String = "*"
    ) async throws -> Int {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }
        guard let mtime = Self.fileMTime(path: filePath.path) else {
            throw DuckDBError.missingDataset
        }

        if let cached = cachedTables[tableName],
           cached.filePath.path == filePath.path,
           cached.mtime == mtime
        {
            return cached.rowCount
        }

        let path = filePath.path
        let count: Int = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    _ = try connection.query("DROP TABLE IF EXISTS \(tableName)")
                    _ = try connection.query("""
                    CREATE TABLE \(tableName) AS
                    SELECT \(projection)
                    FROM read_parquet('\(path)')
                    """)
                    let countResult = try connection.query("SELECT COUNT(*) FROM \(tableName)")
                    let count = countResult[0].cast(to: Int.self)[0] ?? 0
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        cachedTables[tableName] = CachedTable(filePath: filePath, mtime: mtime, rowCount: count)
        return count
    }

    /// Returns a cached COUNT(*) for a parquet file, computing it via `compute` on a miss.
    /// Cache is invalidated by file mtime; pass a `qualifier` to scope the cache (e.g. interval).
    private func cachedParquetCount(
        filePath: URL,
        qualifier: String? = nil,
        compute: @escaping (Connection) throws -> Int
    ) async throws -> Int {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }
        guard let mtime = Self.fileMTime(path: filePath.path) else {
            throw DuckDBError.missingDataset
        }
        let key = qualifier.map { "\(filePath.path)|\($0)" } ?? filePath.path
        if let cached = parquetCountCache[key], cached.mtime == mtime {
            return cached.count
        }
        let count: Int = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try compute(connection))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        parquetCountCache[key] = CachedCount(mtime: mtime, count: count)
        return count
    }

    func loadDataset(filePath: URL) async throws {
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            throw DuckDBError.missingDataset
        }
        _ = try await materializeTableIfNeeded(
            tableName: "price_data",
            filePath: filePath,
            projection: "id, time, symbol, open, high, low, close, volume"
        )
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

        guard let priceTable = cachedTables["price_data"] else {
            throw DuckDBError.missingDataset
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = ["time", "open", "high", "low", "close", "volume"]
        let column = validColumns.contains(sortColumn) ? sortColumn : "time"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "ASC"

        let offset = (page - 1) * pageSize
        let totalCount = priceTable.rowCount

        let priceData: [PriceData] = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let query = """
                    SELECT CAST(time AS VARCHAR), symbol, open, high, low, close, volume
                    FROM price_data
                    ORDER BY \(column) \(direction)
                    LIMIT \(pageSize) OFFSET \(offset)
                    """

                    let result = try connection.query(query)

                    let times = Array(result[0].cast(to: String.self))
                    let symbols = Array(result[1].cast(to: String.self))
                    let opens = Array(result[2].cast(to: Double.self))
                    let highs = Array(result[3].cast(to: Double.self))
                    let lows = Array(result[4].cast(to: Double.self))
                    let closes = Array(result[5].cast(to: Double.self))
                    let volumes = Array(result[6].cast(to: Double.self))

                    let count = times.count
                    var items: [PriceData] = []
                    items.reserveCapacity(count)

                    for i in 0 ..< count {
                        let utcDate = Self.utcDateFormatter.date(from: times[i] ?? "") ?? Date()
                        items.append(PriceData(
                            globalIndex: offset + i,
                            date: utcDate,
                            ticker: symbols[i] ?? "",
                            open: opens[i] ?? 0.0,
                            high: highs[i] ?? 0.0,
                            low: lows[i] ?? 0.0,
                            close: closes[i] ?? 0.0,
                            volume: volumes[i] ?? 0.0
                        ))
                    }
                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        return PaginationResult(
            items: priceData,
            total: totalCount,
            page: page,
            pageSize: pageSize
        )
    }

    /// Get total row count for a dataset
    func getTotalCount(for filePath: URL) async throws -> Int {
        try await cachedParquetCount(filePath: filePath) { connection in
            let countResult = try connection.query("""
            SELECT COUNT(*) as total
            FROM read_parquet('\(filePath.path)')
            """)
            return countResult[0].cast(to: Int.self)[0] ?? 0
        }
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

        return dataFrame.rows.enumerated().map { index, row in
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
        // For 1s interval, use existing count (no aggregation)
        if interval == .oneSecond {
            return try await getTotalCount(for: filePath)
        }

        // Build time bucket expression based on whether this is a standard or non-standard interval
        let timeBucketExpr = Self.timeBucketExpression(for: interval)
        let qualifier = "agg:\(interval.rawValue)"

        return try await cachedParquetCount(filePath: filePath, qualifier: qualifier) { connection in
            let countResult = try connection.query("""
            SELECT COUNT(*) as total
            FROM (
                SELECT \(timeBucketExpr) as interval_time
                FROM read_parquet('\(filePath.path)')
                GROUP BY interval_time
            ) subquery
            """)
            return countResult[0].cast(to: Int.self)[0] ?? 0
        }
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

        // Return empty results if file doesn't exist (e.g. live trading before any trades occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return PaginationResult(items: [], total: 0, page: page, pageSize: pageSize)
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = [
            "order_id", "symbol", "order_type", "quantity", "price",
            "timestamp", "is_completed", "reason", "message",
            "strategy_name", "executed_at", "executed_qty", "executed_price",
            "commission", "pnl", "cumulative_pnl", "position_type",
            "open_position_qty", "balance",
        ]
        let column = validColumns.contains(sortColumn) ? sortColumn : "timestamp"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "DESC"

        let totalCount = try await materializeTableIfNeeded(
            tableName: "trades_data",
            filePath: filePath
        )

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
            cumulative_pnl,
            position_type,
            open_position_qty,
            balance
        FROM trades_data
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let orderIds = Array(result[0].cast(to: String.self))
        let symbols = Array(result[1].cast(to: String.self))
        let orderTypes = Array(result[2].cast(to: String.self))
        let quantities = Array(result[3].cast(to: Double.self))
        let prices = Array(result[4].cast(to: Double.self))
        let timestamps = Array(result[5].cast(to: String.self))
        let isCompleteds = Array(result[6].cast(to: Bool.self))
        let reasons = Array(result[7].cast(to: String.self))
        let messages = Array(result[8].cast(to: String.self))
        let strategyNames = Array(result[9].cast(to: String.self))
        let executedAts = Array(result[10].cast(to: String.self))
        let executedQtys = Array(result[11].cast(to: Double.self))
        let executedPrices = Array(result[12].cast(to: Double.self))
        let commissions = Array(result[13].cast(to: Double.self))
        let pnls = Array(result[14].cast(to: Double.self))
        let cumulativePnls = Array(result[15].cast(to: Double.self))
        let positionTypes = Array(result[16].cast(to: String.self))
        let openPositionQtys = Array(result[17].cast(to: Double.self))
        let balances = Array(result[18].cast(to: Double.self))

        let count = orderIds.count
        var trades: [Trade] = []
        trades.reserveCapacity(count)
        for i in 0 ..< count {
            let timestamp = Self.utcDateFormatter.date(from: timestamps[i] ?? "") ?? Date()
            let executedAt = executedAts[i].flatMap { Self.utcDateFormatter.date(from: $0) }
            trades.append(Trade(
                orderId: orderIds[i] ?? "",
                symbol: symbols[i] ?? "",
                side: OrderSide(rawValue: orderTypes[i] ?? "") ?? .buy,
                quantity: quantities[i] ?? 0.0,
                price: prices[i] ?? 0.0,
                timestamp: timestamp,
                isCompleted: isCompleteds[i] ?? false,
                reason: reasons[i] ?? "",
                message: messages[i] ?? "",
                strategyName: strategyNames[i] ?? "",
                executedAt: executedAt,
                executedQty: executedQtys[i] ?? 0.0,
                executedPrice: executedPrices[i] ?? 0.0,
                commission: commissions[i] ?? 0.0,
                pnl: pnls[i] ?? 0.0,
                cumulativePnl: cumulativePnls[i] ?? 0.0,
                positionType: positionTypes[i] ?? "",
                openPositionQty: openPositionQtys[i] ?? 0.0,
                balance: balances[i] ?? 0.0
            ))
        }

        return PaginationResult(
            items: trades,
            total: totalCount,
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

        // Return empty results if file doesn't exist (e.g. live trading before any orders occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return PaginationResult(items: [], total: 0, page: page, pageSize: pageSize)
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

        let totalCount = try await materializeTableIfNeeded(
            tableName: "orders_data",
            filePath: filePath
        )

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
            status
        FROM orders_data
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let orderIds = Array(result[0].cast(to: String.self))
        let symbols = Array(result[1].cast(to: String.self))
        let orderTypes = Array(result[2].cast(to: String.self))
        let quantities = Array(result[3].cast(to: Double.self))
        let prices = Array(result[4].cast(to: Double.self))
        let timestamps = Array(result[5].cast(to: String.self))
        let isCompleteds = Array(result[6].cast(to: Bool.self))
        let reasons = Array(result[7].cast(to: String.self))
        let messages = Array(result[8].cast(to: String.self))
        let strategyNames = Array(result[9].cast(to: String.self))
        let positionTypes = Array(result[10].cast(to: String.self))
        let statuses = Array(result[11].cast(to: String.self))

        let count = orderIds.count
        var orders: [Order] = []
        orders.reserveCapacity(count)
        for i in 0 ..< count {
            let timestamp = Self.utcDateFormatter.date(from: timestamps[i] ?? "") ?? Date()
            orders.append(Order(
                orderId: orderIds[i] ?? "",
                symbol: symbols[i] ?? "",
                orderType: orderTypes[i] ?? "",
                quantity: quantities[i] ?? 0.0,
                price: prices[i] ?? 0.0,
                timestamp: timestamp,
                isCompleted: isCompleteds[i] ?? false,
                reason: reasons[i] ?? "",
                message: messages[i] ?? "",
                strategyName: strategyNames[i] ?? "",
                positionType: positionTypes[i] ?? "",
                // fallback to .filled if status is unrecognized since it is the default status
                status: OrderStatus(rawValue: statuses[i] ?? "") ?? .filled
            ))
        }

        return PaginationResult(
            items: orders,
            total: totalCount,
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

        // Return empty results if file doesn't exist (e.g. live trading before any marks occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return PaginationResult(items: [], total: 0, page: page, pageSize: pageSize)
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = [
            "id", "market_data_id", "signal_type", "signal_name", "signal_time",
            "signal_symbol", "color", "shape", "title", "message", "category",
        ]
        let column = validColumns.contains(sortColumn) ? sortColumn : "id"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "ASC"

        let totalCount = try await materializeTableIfNeeded(
            tableName: "marks_data",
            filePath: filePath
        )

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination and sorting
        let query = """
        SELECT
            CAST(id AS VARCHAR),
            market_data_id,
            signal_type,
            signal_name,
            CAST(signal_time AS VARCHAR),
            signal_symbol,
            color,
            shape,
            title,
            message,
            category,
            level
        FROM marks_data
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let ids = Array(result[0].cast(to: String.self))
        let signalTypes = Array(result[2].cast(to: String.self))
        let signalNames = Array(result[3].cast(to: String.self))
        let signalTimes = Array(result[4].cast(to: String.self))
        let signalSymbols = Array(result[5].cast(to: String.self))
        let colors = Array(result[6].cast(to: String.self))
        let shapes = Array(result[7].cast(to: String.self))
        let titles = Array(result[8].cast(to: String.self))
        let messages = Array(result[9].cast(to: String.self))
        let categories = Array(result[10].cast(to: String.self))
        let levels = Array(result[11].cast(to: String.self))

        let count = ids.count
        var marks: [Mark] = []
        marks.reserveCapacity(count)
        for i in 0 ..< count {
            let shape = MarkShape(rawValue: shapes[i] ?? "circle") ?? .circle
            let signalTime = Self.utcDateFormatter.date(from: signalTimes[i] ?? "") ?? Date()
            let signalType = SignalType(rawValue: signalTypes[i] ?? "") ?? .noAction
            let signal = Signal(
                time: signalTime,
                type: signalType,
                name: signalNames[i] ?? "",
                reason: "",
                rawValue: "",
                symbol: signalSymbols[i] ?? "",
                indicator: ""
            )
            let markColor = MarkColor(string: colors[i] ?? "#FFFFFF")
            let markLevel = MarkLevel(rawValue: levels[i] ?? "info") ?? .info

            marks.append(Mark(
                id: ids[i] ?? "0",
                color: markColor,
                shape: shape,
                title: titles[i] ?? "",
                message: messages[i] ?? "",
                category: categories[i] ?? "",
                signal: signal,
                level: markLevel
            ))
        }

        return PaginationResult(
            items: marks,
            total: totalCount,
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

        return dataFrame.rows.enumerated().map { index, row in
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

        // Return empty results if file doesn't exist (e.g. live trading before any trades occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return []
        }

        let startTimeStr = Self.utcDateFormatter.string(from: startTime)
        let endTimeStr = Self.utcDateFormatter.string(from: endTime)

        _ = try await materializeTableIfNeeded(
            tableName: "trades_data",
            filePath: filePath
        )

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
            cumulative_pnl,
            position_type,
            open_position_qty,
            balance
        FROM trades_data
        WHERE timestamp >= '\(startTimeStr)' AND timestamp <= '\(endTimeStr)'
        ORDER BY timestamp ASC
        """

        let result = try connection.query(query)

        let orderIds = Array(result[0].cast(to: String.self))
        let symbols = Array(result[1].cast(to: String.self))
        let orderTypes = Array(result[2].cast(to: String.self))
        let quantities = Array(result[3].cast(to: Double.self))
        let prices = Array(result[4].cast(to: Double.self))
        let timestamps = Array(result[5].cast(to: String.self))
        let isCompleteds = Array(result[6].cast(to: Bool.self))
        let reasons = Array(result[7].cast(to: String.self))
        let messages = Array(result[8].cast(to: String.self))
        let strategyNames = Array(result[9].cast(to: String.self))
        let executedAts = Array(result[10].cast(to: String.self))
        let executedQtys = Array(result[11].cast(to: Double.self))
        let executedPrices = Array(result[12].cast(to: Double.self))
        let commissions = Array(result[13].cast(to: Double.self))
        let pnls = Array(result[14].cast(to: Double.self))
        let cumulativePnls = Array(result[15].cast(to: Double.self))
        let positionTypes = Array(result[16].cast(to: String.self))
        let openPositionQtys = Array(result[17].cast(to: Double.self))
        let balances = Array(result[18].cast(to: Double.self))

        let count = orderIds.count
        var trades: [Trade] = []
        trades.reserveCapacity(count)
        for i in 0 ..< count {
            let timestamp = Self.utcDateFormatter.date(from: timestamps[i] ?? "") ?? Date()
            let executedAt = executedAts[i].flatMap { Self.utcDateFormatter.date(from: $0) }
            trades.append(Trade(
                orderId: orderIds[i] ?? "",
                symbol: symbols[i] ?? "",
                side: OrderSide(rawValue: orderTypes[i] ?? "") ?? .buy,
                quantity: quantities[i] ?? 0.0,
                price: prices[i] ?? 0.0,
                timestamp: timestamp,
                isCompleted: isCompleteds[i] ?? false,
                reason: reasons[i] ?? "",
                message: messages[i] ?? "",
                strategyName: strategyNames[i] ?? "",
                executedAt: executedAt,
                executedQty: executedQtys[i] ?? 0.0,
                executedPrice: executedPrices[i] ?? 0.0,
                commission: commissions[i] ?? 0.0,
                pnl: pnls[i] ?? 0.0,
                cumulativePnl: cumulativePnls[i] ?? 0.0,
                positionType: positionTypes[i] ?? "",
                openPositionQty: openPositionQtys[i] ?? 0.0,
                balance: balances[i] ?? 0.0
            ))
        }
        return trades
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

        // Return empty results if file doesn't exist (e.g. live trading before any marks occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return []
        }

        // ISO8601 date formatter for signal_time (format: 2022-12-31T15:30:00.000Z)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let startTimeStr = iso8601Formatter.string(from: startTime)
        let endTimeStr = iso8601Formatter.string(from: endTime)

        _ = try await materializeTableIfNeeded(
            tableName: "marks_data",
            filePath: filePath
        )

        // Query marks within time range
        let query = """
        SELECT
            CAST(id AS VARCHAR),
            market_data_id,
            signal_type,
            signal_name,
            CAST(signal_time AS VARCHAR),
            signal_symbol,
            color,
            shape,
            title,
            message,
            category,
            level
        FROM marks_data
        WHERE signal_time >= '\(startTimeStr)' AND signal_time <= '\(endTimeStr)'
        ORDER BY signal_time ASC
        """

        let result = try connection.query(query)

        let ids = Array(result[0].cast(to: String.self))
        let signalTypes = Array(result[2].cast(to: String.self))
        let signalNames = Array(result[3].cast(to: String.self))
        let signalTimes = Array(result[4].cast(to: String.self))
        let signalSymbols = Array(result[5].cast(to: String.self))
        let colors = Array(result[6].cast(to: String.self))
        let shapes = Array(result[7].cast(to: String.self))
        let titles = Array(result[8].cast(to: String.self))
        let messages = Array(result[9].cast(to: String.self))
        let categories = Array(result[10].cast(to: String.self))
        let levels = Array(result[11].cast(to: String.self))

        let count = ids.count
        var marks: [Mark] = []
        marks.reserveCapacity(count)
        for i in 0 ..< count {
            let shape = MarkShape(rawValue: shapes[i] ?? "circle") ?? .circle
            let signalTime = Self.utcDateFormatter.date(from: signalTimes[i] ?? "") ?? Date()
            let signalType = SignalType(rawValue: signalTypes[i] ?? "") ?? .noAction
            let signal = Signal(
                time: signalTime,
                type: signalType,
                name: signalNames[i] ?? "",
                reason: "",
                rawValue: "",
                symbol: signalSymbols[i] ?? "",
                indicator: ""
            )
            let markColor = MarkColor(string: colors[i] ?? "#FFFFFF")
            let markLevel = MarkLevel(rawValue: levels[i] ?? "INFO") ?? .info

            marks.append(Mark(
                id: ids[i] ?? "0",
                color: markColor,
                shape: shape,
                title: titles[i] ?? "",
                message: messages[i] ?? "",
                category: categories[i] ?? "",
                signal: signal,
                level: markLevel
            ))
        }
        return marks
    }

    /// Fetch log data from a parquet file with pagination and filtering
    func fetchLogData(
        filePath: URL,
        page: Int = 1,
        pageSize: Int = 100,
        sortColumn: String = "timestamp",
        sortDirection: String = "DESC",
        startTime: FoundationDate? = nil,
        endTime: FoundationDate? = nil,
        levelFilter: LogLevel? = nil
    ) async throws -> PaginationResult<Log> {
        guard let connection = connection else {
            throw DuckDBError.connectionError
        }

        // Return empty results if file doesn't exist (e.g. live trading before any logs occur)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath.path) else {
            return PaginationResult(items: [], total: 0, page: page, pageSize: pageSize)
        }

        // Validate sortColumn to prevent SQL injection
        let validColumns = ["id", "timestamp", "symbol", "level", "message", "fields"]
        let column = validColumns.contains(sortColumn) ? sortColumn : "timestamp"

        // Validate sortDirection to prevent SQL injection
        let direction = (sortDirection == "ASC" || sortDirection == "DESC") ? sortDirection : "DESC"

        // Build WHERE clause
        var whereConditions: [String] = []

        if let startTime = startTime {
            let startTimeStr = Self.utcDateFormatter.string(from: startTime)
            whereConditions.append("timestamp >= '\(startTimeStr)'")
        }

        if let endTime = endTime {
            let endTimeStr = Self.utcDateFormatter.string(from: endTime)
            whereConditions.append("timestamp <= '\(endTimeStr)'")
        }

        if let levelFilter = levelFilter {
            whereConditions.append("level = '\(levelFilter.rawValue)'")
        }

        let whereClause = whereConditions.isEmpty ? "" : "WHERE " + whereConditions.joined(separator: " AND ")

        let unfilteredCount = try await materializeTableIfNeeded(
            tableName: "logs_data",
            filePath: filePath
        )

        // If no filters, the materialized count is the total. Otherwise, run a fast
        // in-memory COUNT against the materialized table.
        let totalCount: Int
        if whereConditions.isEmpty {
            totalCount = unfilteredCount
        } else {
            let countResult = try connection.query("SELECT COUNT(*) FROM logs_data \(whereClause)")
            totalCount = countResult[0].cast(to: Int.self)[0] ?? 0
        }

        // Calculate offset
        let offset = (page - 1) * pageSize

        // Main query with pagination, sorting, and filtering
        let query = """
        SELECT
            id,
            CAST(timestamp AS VARCHAR),
            symbol,
            level,
            message,
            fields
        FROM logs_data
        \(whereClause)
        ORDER BY \(column) \(direction)
        LIMIT \(pageSize) OFFSET \(offset)
        """

        let result = try connection.query(query)

        let ids = Array(result[0].cast(to: Int64.self))
        let timestamps = Array(result[1].cast(to: String.self))
        let symbols = Array(result[2].cast(to: String.self))
        let levels = Array(result[3].cast(to: String.self))
        let messages = Array(result[4].cast(to: String.self))
        let fields = Array(result[5].cast(to: String.self))

        let count = ids.count
        var logs: [Log] = []
        logs.reserveCapacity(count)
        for i in 0 ..< count {
            let timestamp = Self.utcDateFormatter.date(from: timestamps[i] ?? "") ?? Date()
            logs.append(Log(
                id: ids[i] ?? 0,
                timestamp: timestamp,
                symbol: symbols[i] ?? "",
                level: LogLevel(rawValue: levels[i] ?? "INFO") ?? .info,
                message: messages[i] ?? "",
                fields: fields[i] ?? ""
            ))
        }

        return PaginationResult(
            items: logs,
            total: totalCount,
            page: page,
            pageSize: pageSize
        )
    }
}
