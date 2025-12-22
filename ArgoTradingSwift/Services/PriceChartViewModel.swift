//
//  PriceChartViewModel.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import Foundation

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
    private(set) var yAxisDomain: ClosedRange<Double> = 0...100
    private(set) var totalCount: Int = 0
    private(set) var currentOffset: Int = 0
    private(set) var isLoading = false

    // Error handling callback
    var onError: ((String) -> Void)?

    // MARK: - Configuration

    let bufferSize = 300

    // MARK: - Initialization

    init(url: URL, dbService: DuckDBServiceProtocol) {
        self.url = url
        self.dbService = dbService
    }

    // MARK: - Public Methods

    func priceData(at index: Int) -> PriceData? {
        guard index >= 0, index < sortedData.count else { return nil }
        return sortedData[index]
    }

    func loadInitialData() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            try dbService.initDatabase()
            totalCount = try await dbService.getTotalCount(for: url)

            let startOffset = max(0, totalCount - bufferSize)
            currentOffset = startOffset

            let fetchedData = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: startOffset,
                count: bufferSize
            )

            updateCachedProperties(from: fetchedData)
            loadedData = fetchedData
        } catch {
            onError?(error.localizedDescription)
        }

        isLoading = false
    }

    func checkAndLoadMoreData(at index: Int, visibleCount: Int) async {
        guard !isLoading, !sortedData.isEmpty else { return }

        let dataCount = sortedData.count

        if index <= 0 && currentOffset > 0 {
            await loadMoreAtBeginning()
        }

        if index + visibleCount >= dataCount && currentOffset + loadedData.count < totalCount {
            await loadMoreAtEnd()
        }
    }

    // MARK: - Private Methods

    private func updateCachedProperties(from data: [PriceData]) {
        sortedData = data.sorted { $0.date < $1.date }
        rebuildIndexedData()

        guard !data.isEmpty else {
            yAxisDomain = 0...100
            return
        }

        let minY = data.map(\.low).min() ?? 0
        let maxY = data.map(\.high).max() ?? 100
        let range = maxY - minY
        let padding = max(range * 0.05, 0.01)
        yAxisDomain = (minY - padding)...(maxY + padding)
    }

    private func rebuildIndexedData() {
        indexedData = sortedData.enumerated().map { IndexedPrice(index: $0.offset, data: $0.element) }
    }

    private func loadMoreAtBeginning() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let loadCount = min(bufferSize / 2, currentOffset)
            let newOffset = currentOffset - loadCount

            let newData = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: newOffset,
                count: loadCount
            )

            var combinedData = newData + loadedData
            currentOffset = newOffset

            if combinedData.count > bufferSize * 2 {
                combinedData = Array(combinedData.prefix(bufferSize * 2))
            }

            updateCachedProperties(from: combinedData)
            loadedData = combinedData
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }

    private func loadMoreAtEnd() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let currentEnd = currentOffset + loadedData.count
            let loadCount = min(bufferSize / 2, totalCount - currentEnd)

            let newData = try await dbService.fetchPriceDataRange(
                filePath: url,
                startOffset: currentEnd,
                count: loadCount
            )

            var combinedData = loadedData + newData

            if combinedData.count > bufferSize * 2 {
                let trimCount = combinedData.count - bufferSize * 2
                combinedData = Array(combinedData.dropFirst(trimCount))
                currentOffset += trimCount
            }

            updateCachedProperties(from: combinedData)
            loadedData = combinedData
        } catch {
            print("Error loading more data: \(error)")
        }

        isLoading = false
    }
}
