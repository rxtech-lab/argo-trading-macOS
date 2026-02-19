//
//  PriceChartViewModelTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/22/25.
//

@testable import ArgoTradingSwift
import Foundation
import LightweightChart
import Testing

// MARK: - Mock DuckDB Service

class MockDuckDBService: DuckDBServiceProtocol {
    var initDatabaseCalled = false
    var getTotalCountCalled = false
    var fetchPriceDataRangeCalled = false
    var getAggregatedCountCalled = false
    var fetchAggregatedPriceDataRangeCalled = false
    var getOffsetForTimestampCalled = false
    var lastRequestedInterval: ChartTimeInterval?
    var lastRequestedTimestamp: Date?

    var mockTotalCount = 0
    var mockPriceData: [PriceData] = []
    var mockAggregatedCounts: [ChartTimeInterval: Int] = [:]
    var mockOffsetForTimestamp: Int = 0
    var shouldThrowError = false

    func initDatabase() throws {
        initDatabaseCalled = true
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
    }

    func getTotalCount(for filePath: URL) async throws -> Int {
        getTotalCountCalled = true
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        return mockTotalCount
    }

    func fetchPriceDataRange(
        filePath: URL,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData] {
        fetchPriceDataRangeCalled = true
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        let start = min(startOffset, mockPriceData.count)
        let end = min(startOffset + count, mockPriceData.count)
        return Array(mockPriceData[start..<end])
    }

    func getAggregatedCount(for filePath: URL, interval: ChartTimeInterval) async throws -> Int {
        getAggregatedCountCalled = true
        lastRequestedInterval = interval
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        if interval == .oneSecond {
            return mockTotalCount
        }
        return mockAggregatedCounts[interval] ?? (mockTotalCount / interval.seconds)
    }

    func fetchAggregatedPriceDataRange(
        filePath: URL,
        interval: ChartTimeInterval,
        startOffset: Int,
        count: Int
    ) async throws -> [PriceData] {
        fetchAggregatedPriceDataRangeCalled = true
        lastRequestedInterval = interval
        if shouldThrowError {
            throw DuckDBError.connectionError
        }

        if interval == .oneSecond {
            let start = min(startOffset, mockPriceData.count)
            let end = min(startOffset + count, mockPriceData.count)
            return Array(mockPriceData[start..<end])
        }

        let aggregationFactor = interval.seconds
        guard !mockPriceData.isEmpty else { return [] }

        var aggregated: [PriceData] = []
        var i = 0
        while i < mockPriceData.count {
            let sliceEnd = min(i + aggregationFactor, mockPriceData.count)
            let slice = Array(mockPriceData[i..<sliceEnd])
            guard let first = slice.first, let last = slice.last else { break }

            aggregated.append(PriceData(
                globalIndex: aggregated.count,
                date: first.date,
                ticker: first.ticker,
                open: first.open,
                high: slice.map(\.high).max() ?? 0,
                low: slice.map(\.low).min() ?? 0,
                close: last.close,
                volume: slice.map(\.volume).reduce(0, +)
            ))
            i += aggregationFactor
        }

        let start = min(startOffset, aggregated.count)
        let end = min(startOffset + count, aggregated.count)
        return Array(aggregated[start..<end])
    }

    func getOffsetForTimestamp(
        filePath: URL,
        timestamp: Date,
        interval: ChartTimeInterval
    ) async throws -> Int {
        getOffsetForTimestampCalled = true
        lastRequestedTimestamp = timestamp
        lastRequestedInterval = interval
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        if mockOffsetForTimestamp > 0 {
            return mockOffsetForTimestamp
        }
        guard !mockPriceData.isEmpty else { return 0 }
        for (index, data) in mockPriceData.enumerated() {
            if data.date >= timestamp {
                return max(0, index - 1)
            }
        }
        return mockPriceData.count - 1
    }

    func fetchTrades(
        filePath: URL,
        startTime: Date,
        endTime: Date
    ) async throws -> [Trade] {
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        return []
    }

    func fetchMarks(
        filePath: URL,
        startTime: Date,
        endTime: Date
    ) async throws -> [Mark] {
        if shouldThrowError {
            throw DuckDBError.connectionError
        }
        return []
    }
}

// MARK: - Test Helpers

func createMockPriceData(count: Int, basePrice: Double = 100.0, startOffset: Int = 0) -> [PriceData] {
    (0..<count).map { i in
        let price = basePrice + Double(i)
        return PriceData(
            globalIndex: startOffset + i,
            date: Date().addingTimeInterval(Double(i) * 60),
            ticker: "TEST",
            open: price,
            high: price + 2,
            low: price - 1,
            close: price + 1,
            volume: 1000
        )
    }
}

// MARK: - Initial Data Loading Tests

struct InitialDataLoadingTests {
    @Test func loadsDataAtEndOfDataset() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()

        #expect(mockService.initDatabaseCalled)
        #expect(mockService.getAggregatedCountCalled)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        #expect(viewModel.totalCount == 1000)
        // Initial offset should be 1000 - 500 = 500
        #expect(viewModel.currentOffset == 500)
        #expect(viewModel.loadedData.count == 500)
        #expect(!viewModel.isLoading)
    }

    @Test func setsCorrectOffsetAndTotalCount() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 750
        mockService.mockPriceData = createMockPriceData(count: 750)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()

        #expect(viewModel.totalCount == 750)
        // Offset should be 750 - 300 = 450
        #expect(viewModel.currentOffset == 450)
    }

    @Test func emptyDataset_loadsEmpty() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 0
        mockService.mockPriceData = []

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        #expect(viewModel.totalCount == 0)
        #expect(viewModel.loadedData.isEmpty)
        #expect(viewModel.currentOffset == 0)
    }

    @Test func smallDataset_loadsAll() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 50
        mockService.mockPriceData = createMockPriceData(count: 50)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()

        #expect(viewModel.totalCount == 50)
        // Small dataset: offset should be 0
        #expect(viewModel.currentOffset == 0)
        #expect(viewModel.loadedData.count == 50)
    }

    @Test func errorHandling_callsOnError() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.shouldThrowError = true

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        var errorMessage: String?
        viewModel.onError = { message in
            errorMessage = message
        }

        await viewModel.loadInitialData()

        #expect(errorMessage != nil)
        #expect(!viewModel.isLoading)
    }
}

// MARK: - Load More at Beginning Tests

struct LoadMoreAtBeginningTests {
    @Test func prependsDataToLoadedData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()
        let initialCount = viewModel.loadedData.count
        let initialFirstIndex = viewModel.loadedData.first?.globalIndex

        await viewModel.loadMoreAtBeginning()

        // Should have prepended data
        #expect(viewModel.loadedData.count > initialCount)
        #expect(viewModel.loadedData.first?.globalIndex ?? 0 < initialFirstIndex ?? 0)
    }

    @Test func alreadyAtOffset0_doesNothing() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Small dataset, first item should have globalIndex 0
        #expect(viewModel.loadedData.first?.globalIndex == 0)

        mockService.fetchAggregatedPriceDataRangeCalled = false

        await viewModel.loadMoreAtBeginning()

        // Should not have called fetch again
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func emptyLoadedData_returns() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 0
        mockService.mockPriceData = []

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Load with empty dataset
        await viewModel.loadInitialData()
        mockService.fetchAggregatedPriceDataRangeCalled = false

        await viewModel.loadMoreAtBeginning()

        // Should not have called fetch
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func partialLoad_handlesLessDataThanChunkSize() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 350
        mockService.mockPriceData = createMockPriceData(count: 350)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300
        )

        await viewModel.loadInitialData()
        // Offset should be 350 - 300 = 50, so first loaded index is 50
        #expect(viewModel.loadedData.first?.globalIndex == 50)

        await viewModel.loadMoreAtBeginning()

        // Should have loaded remaining items to reach index 0
        #expect(viewModel.loadedData.first?.globalIndex == 0)
    }
}

// MARK: - Load More at End Tests

struct LoadMoreAtEndTests {
    @Test func appendsDataToLoadedData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        // First load initial data (required for scrollToTimestamp to work)
        await viewModel.loadInitialData()

        // Use scrollToTimestamp to position in the middle of the dataset
        // so there's room to load more at the end
        mockService.mockOffsetForTimestamp = 200
        await viewModel.scrollToTimestamp(Date())

        // Now we should be around offset 50 (200 - 150), with data up to ~350
        let lastIndexBefore = viewModel.loadedData.last?.globalIndex ?? 0
        #expect(lastIndexBefore < 999) // Ensure we're not at the end

        await viewModel.loadMoreAtEnd()

        // Should have loaded more data at the end
        let lastIndexAfter = viewModel.loadedData.last?.globalIndex ?? 0
        #expect(lastIndexAfter > lastIndexBefore)
    }

    @Test func alreadyAtEnd_doesNotLoadMore() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Already at end (loaded 0-99 for small dataset)
        let lastIndex = viewModel.loadedData.last?.globalIndex

        mockService.fetchAggregatedPriceDataRangeCalled = false
        await viewModel.loadMoreAtEnd()

        // Last index should be same
        #expect(viewModel.loadedData.last?.globalIndex == lastIndex)
    }

    @Test func partialLoad_handlesLessDataRemaining() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 450
        mockService.mockPriceData = createMockPriceData(count: 450)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300
        )

        // Load at beginning to make room at end
        await viewModel.loadInitialData()
        // Offset is 450 - 300 = 150, so loaded 150-449
        await viewModel.loadMoreAtBeginning()
        // Now loaded from some earlier offset

        await viewModel.loadMoreAtEnd()

        // Should reach the end
        #expect(viewModel.loadedData.last?.globalIndex == 449)
    }
}

// MARK: - Time Interval Tests

struct TimeIntervalTests {
    @Test func defaultsToOneSecond() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        #expect(viewModel.timeInterval == .oneSecond)
    }

    @Test func changingIntervalReloadsData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)
        mockService.mockAggregatedCounts[.oneMinute] = 10

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        mockService.getAggregatedCountCalled = false
        mockService.fetchAggregatedPriceDataRangeCalled = false

        await viewModel.setTimeInterval(.oneMinute)

        #expect(mockService.getAggregatedCountCalled)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        #expect(mockService.lastRequestedInterval == .oneMinute)
        #expect(viewModel.timeInterval == .oneMinute)
    }

    @Test func sameInterval_isNoOp() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        mockService.getAggregatedCountCalled = false
        mockService.fetchAggregatedPriceDataRangeCalled = false

        await viewModel.setTimeInterval(.oneSecond)

        #expect(!mockService.getAggregatedCountCalled)
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func variousIntervals_workCorrectly() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 86400 // 1 day of seconds
        mockService.mockPriceData = createMockPriceData(count: 86400)
        mockService.mockAggregatedCounts[.oneMinute] = 1440
        mockService.mockAggregatedCounts[.oneHour] = 24
        mockService.mockAggregatedCounts[.oneDay] = 1

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        // Test 1-minute interval
        await viewModel.setTimeInterval(.oneMinute)
        #expect(viewModel.timeInterval == .oneMinute)
        #expect(mockService.lastRequestedInterval == .oneMinute)

        // Test 1-hour interval
        await viewModel.setTimeInterval(.oneHour)
        #expect(viewModel.timeInterval == .oneHour)
        #expect(mockService.lastRequestedInterval == .oneHour)

        // Test 1-day interval
        await viewModel.setTimeInterval(.oneDay)
        #expect(viewModel.timeInterval == .oneDay)
        #expect(mockService.lastRequestedInterval == .oneDay)
    }

    @Test func timeIntervalEnumProperties() {
        #expect(ChartTimeInterval.oneSecond.displayName == "1s")
        #expect(ChartTimeInterval.oneMinute.displayName == "1m")
        #expect(ChartTimeInterval.oneHour.displayName == "1h")
        #expect(ChartTimeInterval.oneDay.displayName == "1d")

        #expect(ChartTimeInterval.oneSecond.seconds == 1)
        #expect(ChartTimeInterval.oneMinute.seconds == 60)
        #expect(ChartTimeInterval.oneHour.seconds == 3600)
        #expect(ChartTimeInterval.oneDay.seconds == 86400)
    }

    @Test func allTimeIntervalsAvailable() {
        let allCases = ChartTimeInterval.allCases
        #expect(allCases.count == 16)
        #expect(allCases.contains(.oneSecond))
        #expect(allCases.contains(.oneMinute))
        #expect(allCases.contains(.oneHour))
        #expect(allCases.contains(.oneDay))
    }
}

// MARK: - Scroll to Timestamp Tests

struct ScrollToTimestampTests {
    @Test func timestampWithinLoadedRange_doesNotReload() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 500
        mockService.mockPriceData = createMockPriceData(count: 500)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()
        // Loaded indices 200-499

        // Set mock offset within loaded range
        mockService.mockOffsetForTimestamp = 350
        mockService.fetchAggregatedPriceDataRangeCalled = false

        let targetTimestamp = Date()
        await viewModel.scrollToTimestamp(targetTimestamp)

        #expect(mockService.getOffsetForTimestampCalled)
        // Should NOT reload since 350 is within 200-499
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func timestampOutsideLoadedRange_reloadsAroundTarget() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()
        // Loaded indices 700-999

        // Set mock offset outside loaded range
        mockService.mockOffsetForTimestamp = 100
        mockService.fetchAggregatedPriceDataRangeCalled = false

        await viewModel.scrollToTimestamp(Date())

        #expect(mockService.getOffsetForTimestampCalled)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        // Should have loaded around offset 100
        #expect(viewModel.currentOffset <= 100)
    }

    @Test func timestampAtStart_handlesCorrectly() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()

        mockService.mockOffsetForTimestamp = 5

        await viewModel.scrollToTimestamp(Date())

        // Offset should be 0 (can't go negative)
        #expect(viewModel.currentOffset == 0)
    }

    @Test func timestampAtEnd_handlesCorrectly() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()

        // Target near end (already loaded since initial load goes to end)
        mockService.mockOffsetForTimestamp = 950

        await viewModel.scrollToTimestamp(Date())

        // Should still be near end
        #expect(viewModel.loadedData.last?.globalIndex ?? 0 >= 950)
    }

    @Test func errorFromGetOffset_callsOnError() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        var errorMessage: String?
        viewModel.onError = { message in
            errorMessage = message
        }

        mockService.shouldThrowError = true

        await viewModel.scrollToTimestamp(Date())

        #expect(errorMessage != nil)
    }
}

// MARK: - priceData(at:) Tests

struct PriceDataAtIndexTests {
    @Test func validGlobalIndex_returnsCorrectData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()

        let data = viewModel.priceData(at: 50)
        #expect(data != nil)
        #expect(data?.globalIndex == 50)
    }

    @Test func emptyLoadedData_returnsNil() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 0
        mockService.mockPriceData = []

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        #expect(viewModel.priceData(at: 0) == nil)
        #expect(viewModel.priceData(at: 50) == nil)
    }

    @Test func indexNotInLoadedRange_returnsNil() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 300)

        await viewModel.loadInitialData()
        // Loaded indices 700-999

        // Index 50 is not in loaded range
        #expect(viewModel.priceData(at: 50) == nil)
        // Index 700 should be in range
        #expect(viewModel.priceData(at: 700) != nil)
    }

    @Test func negativeIndex_returnsNil() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()

        #expect(viewModel.priceData(at: -1) == nil)
        #expect(viewModel.priceData(at: -100) == nil)
    }
}

// MARK: - Handle Scroll Change Tests

struct HandleScrollChangeTests {
    @Test func nearStart_triggersLoadMoreAtBeginning() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        let initialFirstIndex = viewModel.loadedData.first?.globalIndex ?? 0

        // Create range near start
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 110)

        await viewModel.handleScrollChange(range)

        // Should have loaded more at beginning
        let newFirstIndex = viewModel.loadedData.first?.globalIndex ?? 0
        #expect(newFirstIndex < initialFirstIndex)
    }

    @Test func nearEnd_triggersLoadMoreAtEnd() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Offset is 1500, loaded 1500-1999

        // First load more at beginning to make room at end
        await viewModel.loadMoreAtBeginning()
        let countBefore = viewModel.loadedData.count

        // Create range near end
        let range = VisibleLogicalRange(localFromIndex: countBefore - 60, localToIndex: countBefore - 10)

        await viewModel.handleScrollChange(range)

        // Should have loaded more at end
        #expect(viewModel.loadedData.count >= countBefore)
    }

    @Test func middleOfData_doesNotTriggerLoading() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        let countBefore = viewModel.loadedData.count

        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Create range in middle
        let range = VisibleLogicalRange(localFromIndex: 250, localToIndex: 350)

        await viewModel.handleScrollChange(range)

        // Should not have loaded anything new (no fetch called)
        #expect(viewModel.loadedData.count == countBefore)
    }
}

// MARK: - Configuration Parameters Tests

struct ConfigurationParametersTests {
    @Test func defaultBufferSizesWorkCorrectly() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        #expect(viewModel.bufferSize == 500)
        #expect(viewModel.loadChunkSize == 500)
        #expect(viewModel.maxBufferSize == 1000)
        #expect(viewModel.trimSize == 333)
    }

    @Test func customBufferSizesAffectDerivedDefaults() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 150
        )

        #expect(viewModel.bufferSize == 150)
        #expect(viewModel.loadChunkSize == 150)
        #expect(viewModel.maxBufferSize == 300)
        #expect(viewModel.trimSize == 100)
    }

    @Test func allParametersCanBeCustomized() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 200,
            loadChunkSize: 100,
            maxBufferSize: 500,
            trimSize: 150
        )

        #expect(viewModel.bufferSize == 200)
        #expect(viewModel.loadChunkSize == 100)
        #expect(viewModel.maxBufferSize == 500)
        #expect(viewModel.trimSize == 150)
    }
}

// MARK: - Visible Time Range Tests

struct VisibleTimeRangeTests {
    @Test func returnsNilWhenEmpty() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 0
        mockService.mockPriceData = []

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        #expect(viewModel.getVisibleTimeRange() == nil)
    }

    @Test func returnsCorrectRangeWithData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()

        let range = viewModel.getVisibleTimeRange()
        #expect(range != nil)
        #expect(range?.lowerBound == viewModel.loadedData.first?.date)
        #expect(range?.upperBound == viewModel.loadedData.last?.date)
    }
}

// MARK: - Scroll Guard Tests

struct ScrollGuardTests {
    @Test func scrollGuard_blocksHandleScrollChangeImmediatelyAfterProgrammaticScroll() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 500-999

        // Trigger programmatic scroll (sets guard)
        mockService.mockOffsetForTimestamp = 250
        await viewModel.scrollToTimestamp(Date())

        // Reset the fetch flag to track if handleScrollChange triggers a load
        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Immediately call handleScrollChange with range near start - should be blocked by guard
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 110)
        await viewModel.handleScrollChange(range)

        // Should NOT have called fetch (guard is active)
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func scrollGuard_expiresAfterDuration() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 500-999

        // Trigger programmatic scroll within loaded range (sets guard but doesn't reload)
        mockService.mockOffsetForTimestamp = 700 // Within 500-999 range
        await viewModel.scrollToTimestamp(Date())

        // Wait for guard to expire (500ms + buffer)
        try await Task.sleep(for: .milliseconds(1000))

        // Reset the fetch flag
        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Now handleScrollChange should work (guard expired)
        let firstIndexBefore = viewModel.loadedData.first?.globalIndex ?? 0
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 110)
        await viewModel.handleScrollChange(range)

        // Should have called fetch (guard expired, loading more at beginning)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func handleScrollChange_worksNormallyWithoutProgrammaticScroll() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 500-999

        let firstIndexBefore = viewModel.loadedData.first?.globalIndex ?? 0

        // Call handleScrollChange without any programmatic scroll - should work normally
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 110)
        await viewModel.handleScrollChange(range)

        // Should have loaded more data at beginning (no guard active)
        let firstIndexAfter = viewModel.loadedData.first?.globalIndex ?? 0
        #expect(firstIndexAfter < firstIndexBefore)
    }
}

// MARK: - Boundary Check Tests

struct HasMoreDataTests {
    @Test func hasMoreDataAtBeginning_emptyData_returnsFalse() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        #expect(!viewModel.hasMoreDataAtBeginning)
    }

    @Test func hasMoreDataAtBeginning_dataStartsAtZero_returnsFalse() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 50
        mockService.mockPriceData = createMockPriceData(count: 50)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Small dataset loads from index 0
        #expect(viewModel.loadedData.first?.globalIndex == 0)
        #expect(!viewModel.hasMoreDataAtBeginning)
    }

    @Test func hasMoreDataAtBeginning_dataStartsAtOffset_returnsTrue() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 500-999
        #expect(viewModel.loadedData.first?.globalIndex == 500)
        #expect(viewModel.hasMoreDataAtBeginning)
    }

    @Test func hasMoreDataAtEnd_emptyData_returnsFalse() {
        let mockService = MockDuckDBService()
        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        #expect(!viewModel.hasMoreDataAtEnd)
    }

    @Test func hasMoreDataAtEnd_allDataLoaded_returnsFalse() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 50
        mockService.mockPriceData = createMockPriceData(count: 50)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Last index is 49, totalCount is 50 → 49 < 50-1 is false
        #expect(viewModel.loadedData.last?.globalIndex == 49)
        #expect(!viewModel.hasMoreDataAtEnd)
    }

    @Test func hasMoreDataAtEnd_moreDataExists_returnsTrue() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 1500-1999, totalCount=2000

        // Load more at beginning so we're not at the end anymore
        await viewModel.loadMoreAtBeginning()
        // Now has data from 1000 to 1999, last index is 1999 = totalCount-1
        #expect(!viewModel.hasMoreDataAtEnd)

        // But if we scrolled to the middle...
        mockService.mockOffsetForTimestamp = 500
        await viewModel.scrollToTimestamp(Date())
        // Now loaded around index 500, last index < 1999
        #expect(viewModel.hasMoreDataAtEnd)
    }
}

// MARK: - Short-circuit Scroll Tests

struct ShortCircuitScrollTests {
    @Test func handleScrollChange_nearStart_allDataLoaded_doesNotFetch() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // All 100 items loaded starting from index 0
        #expect(viewModel.loadedData.first?.globalIndex == 0)
        #expect(!viewModel.hasMoreDataAtBeginning)

        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Scroll near start — should NOT trigger a fetch since all data is loaded
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 60)
        await viewModel.handleScrollChange(range)

        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func handleScrollChange_nearEnd_allDataLoaded_doesNotFetch() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // All 100 items loaded, last index is 99 = totalCount - 1
        #expect(viewModel.loadedData.last?.globalIndex == 99)
        #expect(!viewModel.hasMoreDataAtEnd)

        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Scroll near end — should NOT trigger a fetch since all data is loaded
        let range = VisibleLogicalRange(localFromIndex: 60, localToIndex: 95)
        await viewModel.handleScrollChange(range)

        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func handleScrollChange_nearStart_moreDataAvailable_triggersFetch() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService, bufferSize: 500)

        await viewModel.loadInitialData()
        // Loaded indices 1500-1999
        #expect(viewModel.hasMoreDataAtBeginning)

        let countBefore = viewModel.loadedData.count

        // Scroll near start — should trigger a fetch
        let range = VisibleLogicalRange(localFromIndex: 10, localToIndex: 110)
        await viewModel.handleScrollChange(range)

        // Data count should increase from prepended data
        #expect(viewModel.loadedData.count > countBefore)
    }
}

// MARK: - Overlay Loading Tests

struct OverlayLoadingTests {
    @Test func skipsWhenNoOverlayURLsConfigured() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        // No tradesURL or marksURL provided
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()
        await viewModel.loadVisibleOverlays()

        #expect(viewModel.trades.isEmpty)
        #expect(viewModel.marks.isEmpty)
    }

    @Test func resetOverlayRange_clearsLoadedRange() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData()

        viewModel.resetOverlayRange()

        #expect(viewModel.loadedOverlayRange == nil)
    }
}
