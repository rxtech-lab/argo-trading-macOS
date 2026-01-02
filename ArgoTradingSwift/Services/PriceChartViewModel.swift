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

    // MARK: - State

    private(set) var loadedData: [PriceData] = []
    private(set) var totalCount: Int = 0
    private(set) var currentOffset: Int = 0
    private(set) var isLoading = false
    var initialScrollPosition: Int = 0

    /// Current time interval for chart aggregation
    private(set) var timeInterval: ChartTimeInterval = .oneSecond

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
        bufferSize: Int = 300,
        loadChunkSize: Int? = nil,
        maxBufferSize: Int? = nil,
        trimSize: Int? = nil
    ) {
        self.url = url
        self.dbService = dbService
        self.bufferSize = bufferSize
        self.loadChunkSize = loadChunkSize ?? bufferSize
        self.maxBufferSize = maxBufferSize ?? bufferSize * 2
        self.trimSize = trimSize ?? (bufferSize * 2 / 3)
    }

    // MARK: - Public Methods

    func priceData(at index: Int) -> PriceData? {
        guard !loadedData.isEmpty else { return nil }
        let clampedIndex = max(0, min(index, loadedData.count - 1))
        return loadedData[clampedIndex]
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

    func loadMoreAtBeginning(at globalIndex: Int) async {
        guard !isLoading else { return }
        guard let firstLoadedIndex = loadedData.first?.globalIndex else { return }
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

            var combinedData = newData + loadedData
            logger.info("Loaded complete, new global first index is \(combinedData.first!.globalIndex)")
            currentOffset = newOffset

            // Trim from the end if exceeds max buffer size
            if combinedData.count > maxBufferSize {
                let trimCount = combinedData.count - maxBufferSize
                combinedData = Array(combinedData.dropLast(trimCount))
            }

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

            var combinedData = loadedData + newData
            var actualTrimCount = 0

            // Trim from the beginning if exceeds max buffer size
            if combinedData.count > maxBufferSize {
                actualTrimCount = combinedData.count - maxBufferSize
                combinedData = Array(combinedData.dropFirst(actualTrimCount))
                currentOffset += actualTrimCount
            }

            loadedData = combinedData

            // Scroll position is already a global index, no adjustment needed
            // The visual position is maintained because the global index doesn't change
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }
}
