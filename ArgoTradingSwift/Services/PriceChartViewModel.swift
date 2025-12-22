//
//  PriceChartViewModel.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation
import SwiftUI

struct IndexedPrice: Identifiable {
    let index: Int
    let data: PriceData
    var id: Int { index }
}

@Observable
class PriceChartViewModel {
    // MARK: - Dependencies

    private let dbService: DuckDBServiceProtocol
    private let url: URL

    // MARK: - State

    private(set) var loadedData: [PriceData] = []
    private(set) var sortedData: [PriceData] = []
    private(set) var indexedData: [IndexedPrice] = []
    private var currentDataYAxisDomain: ClosedRange<Double> = 0...100
    private var stableYAxisDomain: ClosedRange<Double>?

    /// Public Y-axis domain that remains stable during scrolling
    var yAxisDomain: ClosedRange<Double> {
        stableYAxisDomain ?? currentDataYAxisDomain
    }
    private(set) var totalCount: Int = 0
    private(set) var currentOffset: Int = 0
    private(set) var isLoading = false
    var scrollPositionIndex: Int = 0

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
        guard !sortedData.isEmpty else { return nil }
        let clampedIndex = max(0, min(index, sortedData.count - 1))
        return sortedData[clampedIndex]
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
        sortedData = []
        indexedData = []
        stableYAxisDomain = nil
        currentOffset = 0
        scrollPositionIndex = 0

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

            updateCachedProperties(from: fetchedData)
            loadedData = fetchedData
            scrollPositionIndex = max(0, sortedData.count - visibleCount)
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

            updateCachedProperties(from: fetchedData)
            loadedData = fetchedData

            // Set initial scroll position to show recent data (end of local array)
            scrollPositionIndex = max(0, sortedData.count - visibleCount)
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
    }

    func checkAndLoadMoreData(at index: Int, visibleCount: Int) async {
        guard !isLoading, !sortedData.isEmpty else { return }

        let dataCount = sortedData.count

        if index <= 0, currentOffset > 0 {
            print("Loading more at beginning...")
            await loadMoreAtBeginning()
        }

        if index + visibleCount >= dataCount, currentOffset + loadedData.count < totalCount {
            print("Loading more at end...")
            await loadMoreAtEnd()
        }
    }

    // MARK: - Private Methods

    private func updateCachedProperties(from data: [PriceData]) {
        sortedData = data.sorted { $0.date < $1.date }
        rebuildIndexedData()

        guard !data.isEmpty else {
            currentDataYAxisDomain = 0...100
            return
        }

        let minY = data.map(\.low).min() ?? 0
        let maxY = data.map(\.high).max() ?? 100
        let range = maxY - minY
        let padding = max(range * 0.05, 0.01)
        currentDataYAxisDomain = (minY - padding)...(maxY + padding)

        // On first load, set the stable domain
        // On subsequent loads, expand it if new data falls outside current bounds
        if let existingDomain = stableYAxisDomain {
            let newLower = min(existingDomain.lowerBound, currentDataYAxisDomain.lowerBound)
            let newUpper = max(existingDomain.upperBound, currentDataYAxisDomain.upperBound)
            stableYAxisDomain = newLower...newUpper
        } else {
            stableYAxisDomain = currentDataYAxisDomain
        }
    }

    private func rebuildIndexedData() {
        indexedData = sortedData.enumerated().map { IndexedPrice(index: $0.offset, data: $0.element) }
    }

    private func loadMoreAtBeginning() async {
        guard !isLoading else { return }
        isLoading = true

        let previousScrollIndex = scrollPositionIndex

        do {
            let loadCount = min(loadChunkSize, currentOffset)
            let newOffset = currentOffset - loadCount

            // Use interval-aware fetch
            let newData = try await dbService.fetchAggregatedPriceDataRange(
                filePath: url,
                interval: timeInterval,
                startOffset: newOffset,
                count: loadCount
            )

            var combinedData = newData + loadedData
            currentOffset = newOffset

            // Trim from the end if exceeds max buffer size
            if combinedData.count > maxBufferSize {
                let trimCount = combinedData.count - maxBufferSize
                combinedData = Array(combinedData.dropLast(trimCount))
            }

            updateCachedProperties(from: combinedData)
            loadedData = combinedData

            // Adjust scroll position by prepended count to maintain visual position
            scrollPositionIndex = previousScrollIndex + newData.count
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    private func loadMoreAtEnd() async {
        guard !isLoading else { return }
        isLoading = true

        let previousScrollIndex = scrollPositionIndex

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

            updateCachedProperties(from: combinedData)
            loadedData = combinedData

            // Adjust scroll position by trimmed count to maintain visual position
            if actualTrimCount > 0 {
                scrollPositionIndex = max(0, previousScrollIndex - actualTrimCount)
            }
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }
}
