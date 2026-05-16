//
//  TradingServiceTests.swift
//  ArgoTradingSwiftTests
//

import Foundation
import Testing
@testable import ArgoTradingSwift

struct TradingServiceProviderStatusTests {
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
