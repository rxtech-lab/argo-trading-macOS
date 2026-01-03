//
//  PriceChartViewModel.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation
import SwiftUI

@Observable
class PriceChartViewModel {
    // MARK: - Dependencies

    private let dbService: DuckDBServiceProtocol
    private let url: URL
    private let tradesURL: URL?
    private let marksURL: URL?

    // MARK: - State

    private(set) var loadedData: [PriceData] = []
    // TotalCount stands for the total number of data available for this dataset
    private(set) var totalCount: Int = 0
    private(set) var currentOffset: Int = 0
    private(set) var isLoading = false
    var initialScrollPosition: Int = 0

    /// Current time interval for chart aggregation
    private(set) var timeInterval: ChartTimeInterval = .oneSecond

    // MARK: - Overlay State

    private(set) var trades: [Trade] = []
    private(set) var marks: [Mark] = []
    private(set) var tradeOverlays: [TradeOverlay] = []
    private(set) var markOverlays: [MarkOverlay] = []
    private(set) var loadedOverlayRange: ClosedRange<Date>?
    private(set) var isLoadingOverlays: Bool = false

    // Error handling callback
    var onError: ((String) -> Void)?

    // MARK: - Configuration

    let bufferSize: Int
    let loadChunkSize: Int
    let maxBufferSize: Int
    let trimSize: Int

    // MARK: - Initialization

    init(
        url: URL,
        dbService: DuckDBServiceProtocol,
        tradesURL: URL? = nil,
        marksURL: URL? = nil,
        bufferSize: Int = 500,
        loadChunkSize: Int? = nil,
        maxBufferSize: Int? = nil,
        trimSize: Int? = nil
    ) {
        self.url = url
        self.dbService = dbService
        self.tradesURL = tradesURL
        self.marksURL = marksURL
        self.bufferSize = bufferSize
        self.loadChunkSize = loadChunkSize ?? bufferSize
        self.maxBufferSize = maxBufferSize ?? bufferSize * 2
        self.trimSize = trimSize ?? (bufferSize * 2 / 3)
    }

    // MARK: - Public Methods

    func priceData(at index: Int) -> PriceData? {
        guard !loadedData.isEmpty else { return nil }
        let priceData = loadedData.first { $0.globalIndex == index }
        return priceData
    }

    /// Set the time interval and reload data
    func setTimeInterval(_ interval: ChartTimeInterval, visibleCount: Int) async {
        guard interval != timeInterval else { return }
        timeInterval = interval
        await reloadDataForInterval(visibleCount: visibleCount)
    }

    /// Reload data when interval changes
    private func reloadDataForInterval(visibleCount: Int) async {
        guard !isLoading else { return }
        isLoading = true

        // Reset state
        loadedData = []
        currentOffset = 0
        initialScrollPosition = 0

        do {
            // Get new total count for the interval
            totalCount = try await dbService.getAggregatedCount(for: url, interval: timeInterval)

            let startOffset = max(0, totalCount - bufferSize)
            currentOffset = startOffset

            let fetchedData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: startOffset,
                count: bufferSize
            )

            loadedData = fetchedData
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
    }

    func loadInitialData(visibleCount: Int) async {
        guard !isLoading else { return }
        isLoading = true

        do {
            try dbService.initDatabase()

            // Use interval-aware count
            totalCount = try await dbService.getAggregatedCount(for: url, interval: timeInterval)

            let startOffset = max(0, totalCount - bufferSize)
            currentOffset = startOffset

            // Use interval-aware fetch
            let fetchedData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: startOffset,
                count: bufferSize
            )

            loadedData = fetchedData

            // Set initial scroll position to show recent data (use global index)
            initialScrollPosition = currentOffset + loadedData.count
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
    }

    /// Scroll to a specific timestamp, loading data if necessary
    /// - Parameters:
    ///   - timestamp: The target timestamp to scroll to
    ///   - visibleCount: Number of visible bars for centering
    func scrollToTimestamp(_ timestamp: Date, visibleCount: Int) async {
        guard !isLoading else { return }

        do {
            // Get the database offset for this timestamp
            let targetOffset = try await dbService.getOffsetForTimestamp(
                filePath: url,
                timestamp: timestamp,
                interval: timeInterval
            )

            // Check if the target is within currently loaded data
            let loadedStart = currentOffset
            let loadedEnd = currentOffset + loadedData.count

            if targetOffset >= loadedStart, targetOffset < loadedEnd {
                // Data already loaded - just update scroll position to center on target
                let maxScrollPosition = currentOffset + loadedData.count - visibleCount
                initialScrollPosition = max(currentOffset, min(targetOffset - visibleCount / 2, maxScrollPosition))
            } else {
                // Need to load data around the target timestamp
                await loadDataAroundOffset(targetOffset, visibleCount: visibleCount)
            }
        } catch {
            onError?(error.localizedDescription)
        }
    }

    /// Load data centered around a specific offset
    private func loadDataAroundOffset(_ targetOffset: Int, visibleCount: Int) async {
        guard !isLoading else { return }
        isLoading = true

        // Reset state for new data chunk
        loadedData = []

        do {
            // Calculate start offset to center the target
            let halfBuffer = bufferSize / 2
            let startOffset = max(0, targetOffset - halfBuffer)
            currentOffset = startOffset

            let fetchedData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: startOffset,
                count: bufferSize
            )

            loadedData = fetchedData

            // Set scroll position to center on target (use global index)
            let maxScrollPosition = currentOffset + loadedData.count - visibleCount
            initialScrollPosition = max(currentOffset, min(targetOffset - visibleCount / 2, maxScrollPosition))
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Private Methods

    @MainActor
    func loadMoreAtBeginning() async {
        guard !isLoading else { return }
        guard let firstData = loadedData.first else {
            return
        }
        let firstLoadedIndex = firstData.globalIndex
        if firstLoadedIndex == 0 {
            // Already at the beginning
            return
        }

        isLoading = true

        do {
            let loadCount = min(loadChunkSize, firstLoadedIndex)
            let newOffset = firstLoadedIndex - loadCount

            // Use interval-aware fetch
            let newData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: newOffset,
                count: loadCount
            )

            let combinedData = newData + loadedData
            logger.info("Loaded complete, new global first index is \(combinedData.first!.globalIndex)")

            loadedData = combinedData

        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    func loadMoreAtEnd() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let currentEnd = currentOffset + loadedData.count
            let loadCount = min(loadChunkSize, totalCount - currentEnd)

            // Use interval-aware fetch
            let newData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: currentEnd,
                count: loadCount
            )

            let combinedData = loadedData + newData
            loadedData = combinedData

            // Scroll position is already a global index, no adjustment needed
            // The visual position is maintained because the global index doesn't change
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    // MARK: - Scroll Handling

    /// Handle scroll range change - loads more data and overlays as needed
    func handleScrollChange(_ range: VisibleLogicalRange) async {
        let firstData = loadedData.first!
        let lastData = loadedData.last!
        if range.isNearStart(threshold: 200) {
            logger.debug("[PriceChartViewModel] Loading more data at beginning \(range.localFromIndex) - \(range.localToIndex), firstData=\(firstData.date), lastData=\(lastData.date)")
            await loadMoreAtBeginning()
            await loadVisibleOverlays()
            return
        }

        if range.isNearEnd(threshold: 50, totalCount: loadedData.count) {
            logger.debug("[PriceChartViewModel] Loading more data at end \(range.localFromIndex) - \(range.localToIndex), firstData=\(firstData.date), lastData=\(lastData.date), vmTotalCount=\(loadedData.count)")
            await loadMoreAtEnd()
            await loadVisibleOverlays()
        }
    }

    // MARK: - Overlay Methods

    /// Get the visible time range from currently loaded data
    func getVisibleTimeRange() -> ClosedRange<Date>? {
        guard !loadedData.isEmpty,
              let first = loadedData.first,
              let last = loadedData.last
        else {
            return nil
        }
        return first.date ... last.date
    }

    /// Reset loaded overlay range to force reload on next call
    func resetOverlayRange() {
        loadedOverlayRange = nil
    }

    /// Load overlays for the visible time range
    func loadVisibleOverlays() async {
        // Skip if no overlay URLs configured
        guard tradesURL != nil || marksURL != nil else { return }

        guard let range = getVisibleTimeRange() else { return }

        // Skip if range is fully covered by already-loaded range
        if let loaded = loadedOverlayRange,
           loaded.lowerBound <= range.lowerBound,
           loaded.upperBound >= range.upperBound
        {
            return
        }

        // Skip if already loading
        guard !isLoadingOverlays else { return }
        isLoadingOverlays = true
        defer { isLoadingOverlays = false }

        do {
            try dbService.initDatabase()

            // Load trades within time range
            if let tradesURL = tradesURL,
               FileManager.default.fileExists(atPath: tradesURL.path)
            {
                trades = try await dbService.fetchTrades(
                    filePath: tradesURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }

            // Load marks within time range
            if let marksURL = marksURL,
               FileManager.default.fileExists(atPath: marksURL.path)
            {
                marks = try await dbService.fetchMarks(
                    filePath: marksURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }

            buildOverlays()
            loadedOverlayRange = range
        } catch {
            onError?("Failed to load overlay data: \(error.localizedDescription)")
        }
    }

    /// Build overlay objects from loaded trades and marks
    private func buildOverlays() {
        tradeOverlays = trades.compactMap { trade in
            let isBuy = trade.side == .buy
            return TradeOverlay(
                id: trade.orderId,
                timestamp: trade.timestamp,
                price: trade.executedPrice,
                isBuy: isBuy,
                trade: trade
            )
        }

        markOverlays = marks.map { mark in
            MarkOverlay(
                id: mark.id,
                mark: mark,
                alignedTime: alignToInterval(mark.signal.time, interval: timeInterval)
            )
        }
    }

    /// Align timestamp to interval boundary (floor to interval start)
    /// This ensures markers match exactly with chart data points for proper rendering
    private func alignToInterval(_ date: Date, interval: ChartTimeInterval) -> Date {
        let seconds = interval.seconds
        let timestamp = date.timeIntervalSince1970
        let aligned = floor(timestamp / Double(seconds)) * Double(seconds)
        return Date(timeIntervalSince1970: aligned)
    }
}
