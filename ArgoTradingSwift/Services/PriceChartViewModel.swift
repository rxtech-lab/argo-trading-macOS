//
//  PriceChartViewModel.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation
import LightweightChart
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

    private enum PendingLoadDirection { case beginning, end }
    private var pendingLoad: PendingLoadDirection?

    /// Current time interval for chart aggregation
    private(set) var timeInterval: ChartTimeInterval = .oneSecond

    // MARK: - Overlay State

    private(set) var trades: [Trade] = []
    private(set) var marks: [Mark] = []
    private(set) var loadedOverlayRange: ClosedRange<Date>?
    private(set) var isLoadingOverlays: Bool = false

    // Error handling callback
    var onError: ((String) -> Void)?

    // MARK: - Scroll Guard

    /// Timestamp of last programmatic scroll to prevent auto-load cascade
    private var lastProgrammaticScrollTime: Date?
    private let scrollGuardDuration: TimeInterval = 0.5 // 500ms guard

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

    // MARK: - Boundary Checks

    var hasMoreDataAtBeginning: Bool {
        guard let firstData = loadedData.first else { return false }
        return firstData.globalIndex > 0
    }

    var hasMoreDataAtEnd: Bool {
        guard let lastData = loadedData.last else { return false }
        return lastData.globalIndex < totalCount - 1
    }

    // MARK: - Public Methods

    func priceData(at index: Int) -> PriceData? {
        guard !loadedData.isEmpty else { return nil }
        let priceData = loadedData.first { $0.globalIndex == index }
        return priceData
    }

    /// Set the time interval and reload data
    func setTimeInterval(_ interval: ChartTimeInterval) async {
        guard interval != timeInterval else { return }
        timeInterval = interval
        await reloadDataForInterval()
    }

    /// Reload data when interval changes
    private func reloadDataForInterval() async {
        guard !isLoading else { return }
        isLoading = true

        // Reset state
        loadedData = []
        currentOffset = 0

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
        await processPendingLoad()
    }

    func loadInitialData() async {
        guard !isLoading else { return }
        isLoading = true

        do {
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
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
        await processPendingLoad()
    }

    /// Scroll to a specific timestamp, loading data if necessary
    /// - Parameters:
    ///   - timestamp: The target timestamp to scroll to
    ///   - visibleCount: Number of visible bars for centering
    func scrollToTimestamp(_ timestamp: Date) async {
        guard !isLoading else { return }

        // Set scroll guard to prevent handleScrollChange from loading data
        lastProgrammaticScrollTime = Date()

        do {
            // Get the database offset for this timestamp
            let targetOffset = try await dbService.getOffsetForTimestamp(
                filePath: url,
                timestamp: timestamp,
                interval: timeInterval
            )

            // Check if the target is within currently loaded data
            guard let firstItem = loadedData.first else {
                return
            }

            guard let lastItem = loadedData.last else {
                return
            }

            let loadedStart = firstItem.globalIndex
            let loadedEnd = lastItem.globalIndex

            if !(targetOffset >= loadedStart && targetOffset < loadedEnd) {
                await loadDataAroundOffset(targetOffset, visibleCount: bufferSize * 2)
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
            let halfBuffer = visibleCount / 2
            let startOffset = max(0, targetOffset - halfBuffer)
            currentOffset = startOffset
            logger.debug("Loading data around offset \(targetOffset), startOffset=\(startOffset), visibleCount=\(visibleCount)")

            let fetchedData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: startOffset,
                count: visibleCount
            )

            loadedData = fetchedData
        } catch {
            onError?(error.localizedDescription)
        }

        // sleep to allow UI to update
        try? await Task.sleep(for: .seconds(0.2))
        isLoading = false
        await processPendingLoad()
    }

    // MARK: - Private Methods

    private func processPendingLoad() async {
        guard let direction = pendingLoad else { return }
        pendingLoad = nil
        logger.info("[processPendingLoad] firing \(String(describing: direction))")
        switch direction {
        case .beginning: await loadMoreAtBeginning()
        case .end: await loadMoreAtEnd()
        }
    }

    @MainActor
    func loadMoreAtBeginning() async {
        guard !isLoading else {
            pendingLoad = .beginning
            logger.debug("[loadMoreAtBeginning] QUEUED: isLoading=true")
            return
        }
        guard let firstData = loadedData.first else {
            logger.debug("[loadMoreAtBeginning] SKIP: loadedData is empty")
            return
        }
        let firstLoadedIndex = firstData.globalIndex
        if firstLoadedIndex == 0 {
            logger.debug("[loadMoreAtBeginning] SKIP: already at beginning (firstLoadedIndex=0)")
            return
        }

        isLoading = true

        do {
            let loadCount = min(loadChunkSize, firstLoadedIndex)
            let newOffset = firstLoadedIndex - loadCount
            logger.info("[loadMoreAtBeginning] START: firstLoadedIndex=\(firstLoadedIndex) loadCount=\(loadCount) newOffset=\(newOffset) currentLoadedCount=\(loadedData.count)")

            // Use interval-aware fetch
            let newData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: newOffset,
                count: loadCount
            )
            logger.info("[loadMoreAtBeginning] FETCHED: \(newData.count) items, firstGlobalIndex=\(newData.first?.globalIndex ?? -1) lastGlobalIndex=\(newData.last?.globalIndex ?? -1)")

            let combinedData = newData + loadedData
            logger.info("[loadMoreAtBeginning] DONE: combinedCount=\(combinedData.count) newFirstGlobalIndex=\(combinedData.first!.globalIndex) newLastGlobalIndex=\(combinedData.last!.globalIndex)")

            loadedData = combinedData

        } catch {
            logger.error("[loadMoreAtBeginning] ERROR: \(error)")
        }

        isLoading = false
        await processPendingLoad()
    }

    func loadMoreAtEnd() async {
        guard !isLoading else {
            pendingLoad = .end
            logger.debug("[loadMoreAtEnd] QUEUED: isLoading=true")
            return
        }
        isLoading = true

        do {
            let currentEnd = currentOffset + loadedData.count
            let loadCount = min(loadChunkSize, totalCount - currentEnd)
            logger.info("[loadMoreAtEnd] START: currentOffset=\(currentOffset) loadedCount=\(loadedData.count) currentEnd=\(currentEnd) loadCount=\(loadCount) totalCount=\(totalCount)")

            // Use interval-aware fetch
            let newData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: currentEnd,
                count: loadCount
            )
            logger.info("[loadMoreAtEnd] FETCHED: \(newData.count) items, firstGlobalIndex=\(newData.first?.globalIndex ?? -1) lastGlobalIndex=\(newData.last?.globalIndex ?? -1)")

            let combinedData = loadedData + newData
            loadedData = combinedData
            logger.info("[loadMoreAtEnd] DONE: combinedCount=\(combinedData.count) newLastGlobalIndex=\(combinedData.last!.globalIndex)")

            // Scroll position is already a global index, no adjustment needed
            // The visual position is maintained because the global index doesn't change
        } catch {
            logger.error("[loadMoreAtEnd] ERROR: \(error)")
        }

        isLoading = false
        await processPendingLoad()
    }

    // MARK: - Scroll Handling

    /// Handle scroll range change - loads more data and overlays as needed
    func handleScrollChange(_ range: VisibleLogicalRange) async {
        // Skip auto-load if within guard period after programmatic scroll
        if let lastScroll = lastProgrammaticScrollTime,
           Date().timeIntervalSince(lastScroll) < scrollGuardDuration
        {
            logger.debug("[handleScrollChange] SKIP: within programmatic-scroll guard period")
            return
        }

        guard let firstData = loadedData.first else {
            logger.debug("[handleScrollChange] SKIP: loadedData.first is nil (empty data)")
            return
        }
        guard let lastData = loadedData.last else {
            logger.debug("[handleScrollChange] SKIP: loadedData.last is nil")
            return
        }

        let nearStart = range.isNearStart(threshold: 200)
        let nearEnd = range.isNearEnd(threshold: 50, totalCount: loadedData.count)
        logger.debug("[handleScrollChange] range[\(range.localFromIndex)..\(range.localToIndex)] loadedCount=\(loadedData.count) firstIdx=\(firstData.globalIndex) lastIdx=\(lastData.globalIndex) totalCount=\(totalCount) nearStart=\(nearStart) hasMoreAtBeginning=\(hasMoreDataAtBeginning) nearEnd=\(nearEnd) hasMoreAtEnd=\(hasMoreDataAtEnd) isLoading=\(isLoading)")

        if nearStart, hasMoreDataAtBeginning {
            logger.info("[handleScrollChange] -> loadMoreAtBeginning (range[\(range.localFromIndex)..\(range.localToIndex)], firstIdx=\(firstData.globalIndex))")
            await loadMoreAtBeginning()
            await loadVisibleOverlays()
            return
        }

        if nearEnd, hasMoreDataAtEnd {
            logger.info("[handleScrollChange] -> loadMoreAtEnd (range[\(range.localFromIndex)..\(range.localToIndex)], lastIdx=\(lastData.globalIndex))")
            await loadMoreAtEnd()
            await loadVisibleOverlays()
            return
        }

        if nearStart, !hasMoreDataAtBeginning {
            logger.debug("[handleScrollChange] near start but no more data at beginning (firstIdx=\(firstData.globalIndex))")
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
            // Fetch trades and marks in parallel — they hit independent files,
            // so the wall-clock cost is bounded by the slower of the two.
            async let tradesTask: [Trade]? = {
                guard let tradesURL = tradesURL,
                      FileManager.default.fileExists(atPath: tradesURL.path)
                else { return nil }
                return try await dbService.fetchTrades(
                    filePath: tradesURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }()

            async let marksTask: [Mark]? = {
                guard let marksURL = marksURL,
                      FileManager.default.fileExists(atPath: marksURL.path)
                else { return nil }
                return try await dbService.fetchMarks(
                    filePath: marksURL,
                    startTime: range.lowerBound,
                    endTime: range.upperBound
                )
            }()

            if let fetchedTrades = try await tradesTask {
                trades = fetchedTrades
            }
            if let fetchedMarks = try await marksTask {
                marks = fetchedMarks
            }

            loadedOverlayRange = range
        } catch {
            onError?("Failed to load overlay data: \(error.localizedDescription)")
        }
    }
}
