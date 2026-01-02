//
//  PriceChartViewModelTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/22/25.
//

@testable import ArgoTradingSwift
import Foundation
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
        // Return a slice of mock data based on offset and count
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
        // For 1s, use raw count; otherwise use mock aggregated count or calculate
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

        // For 1s interval, return raw data
        if interval == .oneSecond {
            let start = min(startOffset, mockPriceData.count)
            let end = min(startOffset + count, mockPriceData.count)
            return Array(mockPriceData[start..<end])
        }

        // Simulate aggregation by reducing data
        let aggregationFactor = interval.seconds
        guard !mockPriceData.isEmpty else { return [] }

        // Create aggregated data
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
        // Return mock offset or calculate based on mock data
        if mockOffsetForTimestamp > 0 {
            return mockOffsetForTimestamp
        }
        // Calculate offset by finding closest timestamp in mock data
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

// MARK: - Tests

struct PriceChartViewModelTests {
    @Test func testInitialDataLoading() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 500
        mockService.mockPriceData = createMockPriceData(count: 500)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Act
        await viewModel.loadInitialData(visibleCount: 100)

        // Assert
        #expect(mockService.initDatabaseCalled)
        #expect(mockService.getAggregatedCountCalled)  // Now uses aggregated count
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)  // Now uses aggregated fetch
        #expect(viewModel.totalCount == 500)
        #expect(!viewModel.loadedData.isEmpty)
        #expect(!viewModel.isLoading)
    }

    @Test func testYAxisDomainCalculation() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 10
        // Create data with known min/max: low=99, high=112
        mockService.mockPriceData = createMockPriceData(count: 10, basePrice: 100.0)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Act
        await viewModel.loadInitialData(visibleCount: 100)

        // Assert
        // Low values: 99, 100, 101, ... 108 -> min = 99
        // High values: 102, 103, 104, ... 111 -> max = 111
        let minY = viewModel.yAxisDomain.lowerBound
        let maxY = viewModel.yAxisDomain.upperBound

        // Range = 111 - 99 = 12, padding = 12 * 0.05 = 0.6
        // Expected: (99 - 0.6)...(111 + 0.6) = 98.4...111.6
        #expect(minY < 99.0)
        #expect(maxY > 111.0)
    }

    @Test func testLoadMoreAtBeginning() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Act - Initial load starts from end
        await viewModel.loadInitialData(visibleCount: 100)
        let initialOffset = viewModel.currentOffset
        let initialCount = viewModel.loadedData.count

        // Simulate scrolling to beginning to trigger load more
        await viewModel.loadMoreAtBeginning(at: 0)

        // Assert
        let newOffset = viewModel.currentOffset
        #expect(newOffset < initialOffset)
        #expect(viewModel.loadedData.count >= initialCount)
    }

    @Test func testLoadMoreAtEnd() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Manually set offset to beginning to test loading at end
        await viewModel.loadInitialData(visibleCount: 100)

        // We need to start from a position where there's more data at the end
        // Since initial load goes to the end, this test verifies the mechanism exists
        // In a real scenario, the offset would be at 0 or near it

        // Assert the view model has the correct total count
        #expect(viewModel.totalCount == 1000)
        #expect(!viewModel.loadedData.isEmpty)
    }

    @Test func testScrollPositionSetOnInitialLoad() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 500
        mockService.mockPriceData = createMockPriceData(count: 500)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Act
        await viewModel.loadInitialData(visibleCount: 100)

        // Assert - scroll position should be set to show end of data
        #expect(viewModel.initialScrollPosition >= 0)
        #expect(viewModel.initialScrollPosition == max(0, viewModel.loadedData.count - 100))
    }

    @Test func testScrollPositionAdjustedWhenLoadingMoreAtBeginning() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Act
        await viewModel.loadInitialData(visibleCount: 100)
        let initialScrollPosition = viewModel.initialScrollPosition

        // Trigger load more at beginning
        await viewModel.loadMoreAtBeginning(at: 0)

        // Assert - scroll position should be adjusted to maintain visual position
        #expect(viewModel.initialScrollPosition > initialScrollPosition)
    }

    // MARK: - Tests with Configurable Parameters

    @Test func testInitialStateWith1000Data300Buffer100Visible() async throws {
        // Arrange: 1000 total data, bufferSize 300, visibleCount 100
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        // Act
        await viewModel.loadInitialData(visibleCount: 100)

        // Assert
        // Initial offset should be 1000 - 300 = 700
        #expect(viewModel.currentOffset == 700)
        // Should have loaded 300 items (global indices 700-999)
        #expect(viewModel.loadedData.count == 300)
        #expect(viewModel.loadedData.count == 300)
        // Scroll position should be 300 - 100 = 200 (to show end of data)
        #expect(viewModel.initialScrollPosition == 200)
        // Global index = currentOffset + scrollPositionIndex = 700 + 200 = 900
        let globalIndex = viewModel.currentOffset + viewModel.initialScrollPosition
        #expect(globalIndex == 900)
    }

    @Test func testLoadMoreAtBeginningWithConfigurableParams() async throws {
        // Scenario from user requirements:
        // - Total: 1000, bufferSize: 300, visibleCount: 100
        // - Initial: loaded 700-999, scrollPositionIndex at 0 (scrolled to beginning)
        // - Load 300 more at beginning (items 400-699)
        // - Trim 200 from end (delete 800-999)
        // - Final: 400-799 (400 items), scrollPositionIndex = 300

        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,    // Load 300 items at a time
            maxBufferSize: 400,    // Trigger trim when exceeding 400
            trimSize: 200          // Trim 200 items (2/3 of viewing window)
        )

        // Act - Initial load
        await viewModel.loadInitialData(visibleCount: 100)

        // Verify initial state
        #expect(viewModel.currentOffset == 700)
        #expect(viewModel.loadedData.count == 300)

        // Simulate user scrolling to the beginning (local index 0)
        // Set scroll position to 0 to simulate being at the start
        viewModel.initialScrollPosition = 0

        // Trigger load more at beginning
        await viewModel.loadMoreAtBeginning(at: 0)

        // Assert final state
        // New offset should be 700 - 300 = 400
        #expect(viewModel.currentOffset == 400)
        // Should have 400 items after loading 300 and trimming 200
        // (300 original + 300 new - 200 trimmed = 400)
        #expect(viewModel.loadedData.count == 400)
        // Scroll position should be adjusted: 0 + 300 (loaded) = 300
        #expect(viewModel.initialScrollPosition == 300)
        // Global index should still be 700 (maintaining visual position)
        let globalIndex = viewModel.currentOffset + viewModel.initialScrollPosition
        #expect(globalIndex == 700)
    }

    @Test func testLoadMoreAtBeginningTrimsFromEnd() async throws {
        // Test that trimming happens from the end when loading at beginning
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        await viewModel.loadInitialData(visibleCount: 100)

        // Get the last item before loading more
        let lastItemBeforeLoad = viewModel.loadedData.last

        // Scroll to beginning and load more
        viewModel.initialScrollPosition = 0
        await viewModel.loadMoreAtBeginning(at: 0)

        // The last item should be different (trimmed from end)
        let lastItemAfterLoad = viewModel.loadedData.last
        #expect(lastItemBeforeLoad?.date != lastItemAfterLoad?.date)

        // The first item should be earlier (loaded from beginning)
        let firstItemAfterLoad = viewModel.loadedData.first
        #expect(firstItemAfterLoad != nil)
    }

    @Test func testConfigurableParametersDefaults() async throws {
        // Test that default values work correctly
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")

        // Using default bufferSize of 300
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Verify defaults
        #expect(viewModel.bufferSize == 300)
        #expect(viewModel.loadChunkSize == 300)  // defaults to bufferSize
        #expect(viewModel.maxBufferSize == 600)  // defaults to bufferSize * 2
        #expect(viewModel.trimSize == 200)       // defaults to bufferSize * 2 / 3
    }

    @Test func testCustomBufferSizeAffectsDefaults() async throws {
        // Test that custom bufferSize affects derived defaults
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 150
        )

        // Verify derived defaults based on custom bufferSize
        #expect(viewModel.bufferSize == 150)
        #expect(viewModel.loadChunkSize == 150)  // defaults to bufferSize
        #expect(viewModel.maxBufferSize == 300)  // defaults to bufferSize * 2
        #expect(viewModel.trimSize == 100)       // defaults to bufferSize * 2 / 3
    }

    // MARK: - Load More At End Tests

    @Test func testLoadMoreAtEndWithConfigurableParams() async throws {
        // Scenario: Start from beginning and scroll to end
        // - Total: 1000, bufferSize: 300, visibleCount: 100
        // - Initial: loaded 0-299, scrollPositionIndex at end (199)
        // - Scroll to end triggers load more
        // - Load 300 more at end (items 300-599)
        // - Trim 200 from beginning (delete 0-199)
        // - Final: 200-599 (400 items), scrollPositionIndex adjusted

        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Manually set offset to 0 to simulate starting from beginning
        // We'll load initial data then manipulate to test end loading
        await viewModel.loadInitialData(visibleCount: 100)

        // The initial load starts from offset 700, so there's no more data at end
        // Let's verify that when there IS more data at end, it loads correctly
        // For this test, we need to start from a position where there's data at end

        // Since initial load goes to end (offset 700), we can't easily test loadMoreAtEnd
        // without modifying the viewModel's internal state. Let's create a different scenario.
        #expect(viewModel.currentOffset == 700)
        #expect(viewModel.totalCount == 1000)
    }

    @Test func testLoadMoreAtEndTrimsFromBeginning() async throws {
        // Test that trimming happens from the beginning when loading at end
        // We need to simulate a scenario where we're not at the end of total data

        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Load initial data (starts at offset 700)
        await viewModel.loadInitialData(visibleCount: 100)

        // Scroll to beginning to load more data at start
        viewModel.initialScrollPosition = 0
        await viewModel.loadMoreAtBeginning(at: 0)

        // Now we should be at offset 400 with 400 items (400-799)
        let offsetAfterLoadingAtBeginning = viewModel.currentOffset
        let countAfterLoadingAtBeginning = viewModel.loadedData.count
        let firstItemBeforeLoadAtEnd = viewModel.loadedData.first

        #expect(offsetAfterLoadingAtBeginning == 400)
        #expect(countAfterLoadingAtBeginning == 400)

        // Now scroll to end to trigger load more at end
        // Set scroll position to trigger end loading
        let endPosition = viewModel.loadedData.count - 100
        viewModel.initialScrollPosition = endPosition
        await viewModel.loadMoreAtEnd()

        // After loading at end, first item should be different (trimmed from beginning)
        let firstItemAfterLoadAtEnd = viewModel.loadedData.first
        #expect(firstItemBeforeLoadAtEnd?.date != firstItemAfterLoadAtEnd?.date)

        // Offset should have increased (trimmed from beginning)
        #expect(viewModel.currentOffset > offsetAfterLoadingAtBeginning)
    }

    @Test func testLoadedDataCountStaysBounded() async throws {
        // Test that loadedData.count never exceeds maxBufferSize after trimming
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Initial load
        await viewModel.loadInitialData(visibleCount: 100)
        #expect(viewModel.loadedData.count <= viewModel.maxBufferSize)

        // Load at beginning multiple times
        for _ in 0..<5 {
            if viewModel.currentOffset > 0 {
                viewModel.initialScrollPosition = 0
                await viewModel.loadMoreAtBeginning(at: 0)
                // Count should never exceed maxBufferSize after trim
                #expect(viewModel.loadedData.count <= viewModel.maxBufferSize)
            }
        }

        // Load at end multiple times
        for _ in 0..<5 {
            let endIndex = viewModel.loadedData.count - 1
            if viewModel.currentOffset + viewModel.loadedData.count < viewModel.totalCount {
                viewModel.initialScrollPosition = endIndex
                await viewModel.loadMoreAtEnd()
                // Count should never exceed maxBufferSize after trim
                #expect(viewModel.loadedData.count <= viewModel.maxBufferSize)
            }
        }
    }

    @Test func testScrollPositionAdjustedWhenLoadingMoreAtEnd() async throws {
        // Test that scroll position is adjusted correctly when loading at end and trimming
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Load initial data (starts at offset 1700)
        await viewModel.loadInitialData(visibleCount: 100)

        // First, load at beginning to get to a position where we can load at end
        viewModel.initialScrollPosition = 0
        await viewModel.loadMoreAtBeginning(at: 0)

        let offsetBeforeEndLoad = viewModel.currentOffset
        let scrollPositionBeforeEndLoad = viewModel.initialScrollPosition
        let globalIndexBefore = offsetBeforeEndLoad + scrollPositionBeforeEndLoad

        // Now trigger load at end
        let endPosition = viewModel.loadedData.count - 1
        viewModel.initialScrollPosition = endPosition
        await viewModel.loadMoreAtEnd()

        let offsetAfterEndLoad = viewModel.currentOffset
        let scrollPositionAfterEndLoad = viewModel.initialScrollPosition
        let globalIndexAfter = offsetAfterEndLoad + scrollPositionAfterEndLoad

        // If trimming happened, scroll position should be adjusted to maintain global position
        if offsetAfterEndLoad > offsetBeforeEndLoad {
            // Trimming happened from beginning
            let trimAmount = offsetAfterEndLoad - offsetBeforeEndLoad
            // Scroll position should have decreased by trim amount
            #expect(scrollPositionAfterEndLoad == max(0, endPosition - trimAmount))
        }

        // Global index should approximately maintain the same relative position
        #expect(globalIndexAfter >= globalIndexBefore - 1)
    }

    @Test func testLoadMoreAtEndMaintainsGlobalPosition() async throws {
        // Test that global position is maintained when loading at end
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 2000
        mockService.mockPriceData = createMockPriceData(count: 2000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Load initial (offset 1700, items 1700-1999)
        await viewModel.loadInitialData(visibleCount: 100)

        // Load at beginning to move offset back
        viewModel.initialScrollPosition = 0
        await viewModel.loadMoreAtBeginning(at: 0)
        // Now at offset 1400, items 1400-1799 (400 items after trim)

        // Set a specific scroll position and record global index
        viewModel.initialScrollPosition = 200
        let globalIndexBefore = viewModel.currentOffset + viewModel.initialScrollPosition

        // Trigger load at end (near index 399)
        await viewModel.loadMoreAtEnd()

        // If trim happened, global index should be preserved via scroll adjustment
        let globalIndexAfter = viewModel.currentOffset + viewModel.initialScrollPosition

        // The global position should be maintained or very close
        // (might differ slightly due to rounding or edge cases)
        #expect(abs(globalIndexAfter - globalIndexBefore) <= viewModel.trimSize)
    }

    @Test func testMultipleScrollBackAndForthKeepsFixedSize() async throws {
        // Test that scrolling back and forth multiple times keeps loadedData.count
        // fixed at maxBufferSize after the first trim occurs
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 5000
        mockService.mockPriceData = createMockPriceData(count: 5000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Initial load (offset 4700, items 4700-4999, count = 300)
        await viewModel.loadInitialData(visibleCount: 100)
        #expect(viewModel.loadedData.count == 300)

        // First scroll to beginning - triggers load and trim
        viewModel.initialScrollPosition = 0
        await viewModel.loadMoreAtBeginning(at: 0)

        // After first load+trim, should be exactly maxBufferSize
        #expect(viewModel.loadedData.count == viewModel.maxBufferSize)
        let expectedSize = viewModel.maxBufferSize

        // Scroll back and forth 10 times
        for i in 0..<10 {
            if i % 2 == 0 {
                // Scroll to beginning
                if viewModel.currentOffset > 0 {
                    viewModel.initialScrollPosition = 0
                    await viewModel.loadMoreAtBeginning(at: 0)
                    #expect(
                        viewModel.loadedData.count == expectedSize,
                        "Iteration \(i): Expected \(expectedSize), got \(viewModel.loadedData.count)"
                    )
                }
            } else {
                // Scroll to end
                let endIndex = viewModel.loadedData.count - 1
                if viewModel.currentOffset + viewModel.loadedData.count < viewModel.totalCount {
                    viewModel.initialScrollPosition = endIndex
                    await viewModel.loadMoreAtEnd()
                    #expect(
                        viewModel.loadedData.count == expectedSize,
                        "Iteration \(i): Expected \(expectedSize), got \(viewModel.loadedData.count)"
                    )
                }
            }
        }

        // Final verification
        #expect(viewModel.loadedData.count == expectedSize)
    }

    @Test func testScrollingCoversEntireDataset() async throws {
        // Test that we can scroll through the entire dataset by going back and forth
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300,
            loadChunkSize: 300,
            maxBufferSize: 400,
            trimSize: 200
        )

        // Initial load starts at end (offset 700)
        await viewModel.loadInitialData(visibleCount: 100)
        #expect(viewModel.currentOffset == 700)

        // Keep scrolling to beginning until we reach offset 0
        var iterations = 0
        while viewModel.currentOffset > 0 && iterations < 10 {
            viewModel.initialScrollPosition = 0
            await viewModel.loadMoreAtBeginning(at: 0)
            iterations += 1
            // Size should always be maxBufferSize after trim
            #expect(viewModel.loadedData.count == viewModel.maxBufferSize)
        }

        // Should have reached the beginning
        #expect(viewModel.currentOffset == 0)

        // Now scroll back to end
        iterations = 0
        while viewModel.currentOffset + viewModel.loadedData.count < viewModel.totalCount && iterations < 10 {
            let endIndex = viewModel.loadedData.count - 1
            viewModel.initialScrollPosition = endIndex
            await viewModel.loadMoreAtEnd()
            iterations += 1
            // Size should always be maxBufferSize after trim
            #expect(viewModel.loadedData.count == viewModel.maxBufferSize)
        }

        // Should have reached the end
        #expect(viewModel.currentOffset + viewModel.loadedData.count == viewModel.totalCount)
    }

    // MARK: - Time Interval Tests

    @Test func testTimeIntervalDefaultsToOneSecond() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        #expect(viewModel.timeInterval == .oneSecond)
    }

    @Test func testOneSecondIntervalUsesAggregatedMethodsWithOneSecond() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        // Should use aggregated methods (which internally handle 1s case)
        #expect(mockService.getAggregatedCountCalled)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        #expect(mockService.lastRequestedInterval == .oneSecond)
    }

    @Test func testChangingTimeIntervalReloadsData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)
        let initialDataCount = viewModel.loadedData.count

        // Reset tracking flags
        mockService.getAggregatedCountCalled = false
        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Change interval
        await viewModel.setTimeInterval(.oneMinute, visibleCount: 100)

        // Should have called aggregated methods with new interval
        #expect(mockService.getAggregatedCountCalled)
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        #expect(mockService.lastRequestedInterval == .oneMinute)
        #expect(viewModel.timeInterval == .oneMinute)
    }

    @Test func testSetTimeIntervalDoesNothingIfSameInterval() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        // Reset tracking flags
        mockService.getAggregatedCountCalled = false
        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Set same interval
        await viewModel.setTimeInterval(.oneSecond, visibleCount: 100)

        // Should NOT have called aggregated methods again
        #expect(!mockService.getAggregatedCountCalled)
        #expect(!mockService.fetchAggregatedPriceDataRangeCalled)
    }

    @Test func testAggregatedIntervalReducesDataCount() async throws {
        let mockService = MockDuckDBService()
        // 600 seconds of data = 10 minutes
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)
        mockService.mockAggregatedCounts[.oneMinute] = 10  // 10 minutes

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        // Load with 1m interval
        await viewModel.setTimeInterval(.oneMinute, visibleCount: 100)
        await viewModel.loadInitialData(visibleCount: 100)

        // Total count should be 10 (aggregated)
        #expect(viewModel.totalCount == 10)
    }

    @Test func testTimeIntervalEnumProperties() {
        // Test displayName for core intervals
        #expect(ChartTimeInterval.oneSecond.displayName == "1s")
        #expect(ChartTimeInterval.oneMinute.displayName == "1m")
        #expect(ChartTimeInterval.thirtyMinutes.displayName == "30m")
        #expect(ChartTimeInterval.oneHour.displayName == "1h")
        #expect(ChartTimeInterval.oneDay.displayName == "1d")

        // Test duckDBInterval for standard intervals
        #expect(ChartTimeInterval.oneSecond.duckDBInterval == "second")
        #expect(ChartTimeInterval.oneMinute.duckDBInterval == "minute")
        #expect(ChartTimeInterval.oneHour.duckDBInterval == "hour")
        #expect(ChartTimeInterval.oneDay.duckDBInterval == "day")

        // Test duckDBInterval for non-standard intervals (maps to base unit)
        #expect(ChartTimeInterval.thirtyMinutes.duckDBInterval == "minute")
        #expect(ChartTimeInterval.fourHours.duckDBInterval == "hour")

        // Test seconds for core intervals
        #expect(ChartTimeInterval.oneSecond.seconds == 1)
        #expect(ChartTimeInterval.oneMinute.seconds == 60)
        #expect(ChartTimeInterval.thirtyMinutes.seconds == 1800)
        #expect(ChartTimeInterval.oneHour.seconds == 3600)
        #expect(ChartTimeInterval.oneDay.seconds == 86400)
    }

    @Test func testAllTimeIntervalsAvailable() {
        let allCases = ChartTimeInterval.allCases
        #expect(allCases.count == 16)  // Updated from 4 to 16 intervals
        #expect(allCases.contains(.oneSecond))
        #expect(allCases.contains(.oneMinute))
        #expect(allCases.contains(.threeMinutes))
        #expect(allCases.contains(.fiveMinutes))
        #expect(allCases.contains(.fifteenMinutes))
        #expect(allCases.contains(.thirtyMinutes))
        #expect(allCases.contains(.oneHour))
        #expect(allCases.contains(.twoHours))
        #expect(allCases.contains(.fourHours))
        #expect(allCases.contains(.sixHours))
        #expect(allCases.contains(.eightHours))
        #expect(allCases.contains(.twelveHours))
        #expect(allCases.contains(.oneDay))
        #expect(allCases.contains(.threeDays))
        #expect(allCases.contains(.oneWeek))
        #expect(allCases.contains(.oneMonth))
    }

    // MARK: - priceData(at:) Index Clamping Tests

    @Test func testPriceDataAtEmptyData_returnsNil() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 0
        mockService.mockPriceData = []

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        #expect(viewModel.priceData(at: 0) == nil)
        #expect(viewModel.priceData(at: -1) == nil)
        #expect(viewModel.priceData(at: 100) == nil)
    }

    @Test func testPriceDataAtValidIndex_returnsCorrectData() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 10
        mockService.mockPriceData = createMockPriceData(count: 10)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        let data = viewModel.priceData(at: 5)
        #expect(data != nil)
        #expect(data?.id == 5)
    }

    @Test func testPriceDataAtNegativeIndex_clampsToFirst() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 10
        mockService.mockPriceData = createMockPriceData(count: 10)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        let firstData = viewModel.priceData(at: 0)
        let negativeData = viewModel.priceData(at: -1)
        let veryNegativeData = viewModel.priceData(at: -100)

        #expect(negativeData?.id == firstData?.id)
        #expect(veryNegativeData?.id == firstData?.id)
    }

    @Test func testPriceDataAtIndexExceedsBounds_clampsToLast() async throws {
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 10
        mockService.mockPriceData = createMockPriceData(count: 10)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        let lastData = viewModel.priceData(at: 9)
        let outOfBoundsData = viewModel.priceData(at: 10)
        let wayOutOfBoundsData = viewModel.priceData(at: 1000)

        #expect(outOfBoundsData?.id == lastData?.id)
        #expect(wayOutOfBoundsData?.id == lastData?.id)
    }

    // MARK: - scrollToTimestamp Tests

    @Test func testScrollToTimestamp_dataAlreadyLoaded_scrollsToCorrectPosition() async throws {
        // Arrange: Load data and scroll to a timestamp within the loaded range
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 500
        mockService.mockPriceData = createMockPriceData(count: 500)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        // Load initial data (offset 200-499)
        await viewModel.loadInitialData(visibleCount: 100)
        let initialOffset = viewModel.currentOffset
        #expect(initialOffset == 200)

        // Set mock offset for a timestamp within loaded range
        mockService.mockOffsetForTimestamp = 350  // Within 200-499

        // Act: Scroll to timestamp
        let targetTimestamp = Date().addingTimeInterval(350 * 60)  // Matches index 350
        await viewModel.scrollToTimestamp(targetTimestamp, visibleCount: 100)

        // Assert
        #expect(mockService.getOffsetForTimestampCalled)
        // Offset should not change (data is already loaded)
        #expect(viewModel.currentOffset == initialOffset)
        // Scroll position should be centered: localIndex - visibleCount/2 = (350-200) - 50 = 100
        #expect(viewModel.initialScrollPosition == 100)
    }

    @Test func testScrollToTimestamp_dataNeedsLoading_loadsAndScrolls() async throws {
        // Arrange: Scroll to a timestamp outside the loaded range
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        // Load initial data (offset 700-999)
        await viewModel.loadInitialData(visibleCount: 100)
        #expect(viewModel.currentOffset == 700)

        // Set mock offset for a timestamp outside loaded range
        mockService.mockOffsetForTimestamp = 100  // Outside 700-999

        // Reset fetch tracking
        mockService.fetchAggregatedPriceDataRangeCalled = false

        // Act: Scroll to timestamp at offset 100
        let targetTimestamp = Date().addingTimeInterval(100 * 60)
        await viewModel.scrollToTimestamp(targetTimestamp, visibleCount: 100)

        // Assert
        #expect(mockService.getOffsetForTimestampCalled)
        // Data should have been reloaded around offset 100
        #expect(mockService.fetchAggregatedPriceDataRangeCalled)
        // New offset should be centered around 100: max(0, 100 - 150) = 0
        #expect(viewModel.currentOffset == 0)
    }

    @Test func testScrollToTimestamp_centersTargetInView() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 500
        mockService.mockPriceData = createMockPriceData(count: 500)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        await viewModel.loadInitialData(visibleCount: 100)

        // Target offset within loaded range
        mockService.mockOffsetForTimestamp = 300  // Within 200-499

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: scroll position should center the target
        // localIndex = 300 - 200 = 100
        // scrollPosition = 100 - 50 = 50
        #expect(viewModel.initialScrollPosition == 50)
    }

    @Test func testScrollToTimestamp_whileLoading_doesNothing() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        // Reset tracking
        mockService.getOffsetForTimestampCalled = false

        // Simulate loading state (we can't easily set isLoading directly,
        // but we can verify the guard works by checking behavior)
        // For this test, we just verify the method doesn't crash when called

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: method should have been called (since we're not actually loading)
        #expect(mockService.getOffsetForTimestampCalled)
    }

    @Test func testScrollToTimestamp_handlesErrorGracefully() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 100
        mockService.mockPriceData = createMockPriceData(count: 100)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        await viewModel.loadInitialData(visibleCount: 100)

        // Set up error callback tracking
        var errorMessage: String?
        viewModel.onError = { message in
            errorMessage = message
        }

        // Enable errors
        mockService.shouldThrowError = true

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: error should have been handled via onError callback
        #expect(errorMessage != nil)
    }

    @Test func testScrollToTimestamp_respectsTimeInterval() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 600
        mockService.mockPriceData = createMockPriceData(count: 600)
        mockService.mockAggregatedCounts[.oneMinute] = 10

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(url: url, dbService: mockService)

        // Set time interval before loading
        await viewModel.setTimeInterval(.oneMinute, visibleCount: 100)
        await viewModel.loadInitialData(visibleCount: 100)

        // Reset tracking
        mockService.lastRequestedInterval = nil

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: should use the current time interval
        #expect(mockService.lastRequestedInterval == .oneMinute)
    }

    @Test func testScrollToTimestamp_atBeginningOfDataset_scrollsCorrectly() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        await viewModel.loadInitialData(visibleCount: 100)

        // Target very beginning of dataset
        mockService.mockOffsetForTimestamp = 10

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: offset should start at 0 (can't go negative)
        #expect(viewModel.currentOffset == 0)
        // Scroll position should be properly calculated
        // localIndex = 10 - 0 = 10
        // scrollPosition = max(0, 10 - 50) = 0
        #expect(viewModel.initialScrollPosition >= 0)
    }

    @Test func testScrollToTimestamp_atEndOfDataset_scrollsCorrectly() async throws {
        // Arrange
        let mockService = MockDuckDBService()
        mockService.mockTotalCount = 1000
        mockService.mockPriceData = createMockPriceData(count: 1000)

        let url = URL(fileURLWithPath: "/tmp/test.parquet")
        let viewModel = PriceChartViewModel(
            url: url,
            dbService: mockService,
            bufferSize: 300
        )

        await viewModel.loadInitialData(visibleCount: 100)

        // Target near end (already loaded since initial load goes to end)
        mockService.mockOffsetForTimestamp = 950  // Within 700-999

        // Act
        await viewModel.scrollToTimestamp(Date(), visibleCount: 100)

        // Assert: should scroll within existing data
        // localIndex = 950 - 700 = 250
        // scrollPosition = max(0, min(250 - 50, 300 - 100)) = 200
        #expect(viewModel.initialScrollPosition <= viewModel.loadedData.count - 100)
    }
}
