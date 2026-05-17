//
//  TradingServiceTests.swift
//  ArgoTradingSwiftTests
//

import Foundation
import Testing
@testable import ArgoTradingSwift

struct TradingServiceProviderStatusTests {
    @MainActor
    @Test func liveDataChangeMapsCategoriesAndDropsStaleSequences() async throws {
        let service = TradingService()

        service.recordLiveDataChanged(
            runId: "run_1",
            categories: ["market_data", "marks", "unknown"],
            finalized: false,
            sequence: 2
        )

        #expect(service.liveDataChange?.runID == "run_1")
        #expect(service.liveDataChange?.categories == [.marketData, .marks])
        #expect(service.liveDataChange?.finalized == false)
        #expect(service.liveDataChange?.sequence == 2)

        service.recordLiveDataChanged(
            runId: "run_1",
            categories: ["logs"],
            finalized: false,
            sequence: 1
        )

        #expect(service.liveDataChange?.categories == [.marketData, .marks])
        #expect(service.liveDataChange?.sequence == 2)
    }

    @MainActor
    @Test func finalizedLiveDataChangeDefaultsToAllCategoriesWhenBackendSendsNone() async throws {
        let service = TradingService()

        service.recordLiveDataChanged(
            runId: "run_1",
            categories: [],
            finalized: true,
            sequence: 1
        )

        #expect(service.liveDataChange?.categories == Set(LiveTradingDataCategory.allCases))
        #expect(service.liveDataChange?.finalized == true)
    }

    @MainActor
    @Test func providerStatusChangeUpdatesToolbarStatus() async throws {
        let service = TradingService()
        let toolbarStatusService = ToolbarStatusService()
        service.toolbarStatusService = toolbarStatusService

        try service.onProviderStatusChange("connected", tradingStatus: "disconnected")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(toolbarStatusService.toolbarRunningStatus == .trading(
            label: "Trading",
            phase: "Disconnected",
            progress: nil,
            message: "Trading provider disconnected"
        ))
    }

    @MainActor
    @Test func providerErrorIsNotHiddenByLaterRunningStatus() async throws {
        let service = TradingService()
        let toolbarStatusService = ToolbarStatusService()
        service.toolbarStatusService = toolbarStatusService
        let error = NSError(
            domain: "TradingProvider",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "trading provider connection check failed"]
        )

        service.onError(error)
        try await Task.sleep(nanoseconds: 50_000_000)
        try service.onStatusUpdate("running")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(toolbarStatusService.toolbarRunningStatus == .trading(
            label: "Trading",
            phase: "Provider error",
            progress: nil,
            message: "trading provider connection check failed"
        ))
    }

    @MainActor
    @Test func providerErrorIsNotClearedByEngineStoppedStatus() async throws {
        let service = TradingService()
        let toolbarStatusService = ToolbarStatusService()
        service.toolbarStatusService = toolbarStatusService
        let error = NSError(
            domain: "TradingProvider",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "trading provider connection check failed"]
        )

        service.onError(error)
        try await Task.sleep(nanoseconds: 50_000_000)
        try service.onStatusUpdate("stopped")
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(toolbarStatusService.toolbarRunningStatus == .trading(
            label: "Trading",
            phase: "Provider error",
            progress: nil,
            message: "trading provider connection check failed"
        ))
    }

    @MainActor
    @Test func providerErrorIsNotClearedByCleanEngineStop() async throws {
        let service = TradingService()
        let toolbarStatusService = ToolbarStatusService()
        service.toolbarStatusService = toolbarStatusService
        let error = NSError(
            domain: "TradingProvider",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "trading provider connection check failed"]
        )

        service.onError(error)
        try await Task.sleep(nanoseconds: 50_000_000)
        service.onEngineStop(nil)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(toolbarStatusService.toolbarRunningStatus == .trading(
            label: "Trading",
            phase: "Provider error",
            progress: nil,
            message: "trading provider connection check failed"
        ))
    }
}
