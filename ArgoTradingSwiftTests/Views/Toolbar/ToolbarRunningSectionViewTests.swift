//
//  ToolbarRunningSectionViewTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/25/25.
//

import Testing
import SwiftUI
import ViewInspector
@testable import ArgoTradingSwift

private func makeStatusService(_ status: ToolbarRunningStatus) -> ToolbarStatusService {
    let service = ToolbarStatusService()
    service.setStatusImmediately(status)
    return service
}

// MARK: - Status View Rendering Tests

struct ToolbarRunningStatusBadgeViewTests {

    @MainActor
    @Test func idleStatusDisplaysIdleText() throws {
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.idle))

        let text = try sut.inspect().find(text: "Idle")
        #expect(try text.string() == "Idle")
    }

    @MainActor
    @Test func runningStatusDisplaysLabel() throws {
        let label = "Building..."
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.running(label: label)))

        let labelText = try sut.inspect().find(text: label)
        #expect(try labelText.string() == label)
    }

    @MainActor
    @Test func downloadingStatusDisplaysDownloadingLabel() throws {
        let label = "BTCUSDT"
        let progress = Progress(current: 50, total: 100)
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.downloading(label: label, progress: progress)))

        let downloadText = try sut.inspect().find(text: "Downloading \(label)")
        #expect(try downloadText.string() == "Downloading \(label)")
    }

    @MainActor
    @Test func backtestingStatusDisplaysLabelAndCounts() throws {
        let label = "Backtesting"
        let progress = Progress(current: 45, total: 100)
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.backtesting(label: label, progress: progress)))

        let expectedText = "\(label) \(progress.current)/\(progress.total)"
        let labelText = try sut.inspect().find(text: expectedText)
        #expect(try labelText.string() == expectedText)
    }

    @MainActor
    @Test func errorStatusDisplaysXmarkImage() throws {
        let label = "Build"
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.error(label: label, errors: ["Error"], at: Date())))

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasXmark = images.contains { image in
            (try? image.actualImage().name() == "xmark.circle.fill") ?? false
        }
        #expect(hasXmark)
    }

    @MainActor
    @Test func downloadCancelledStatusDisplaysXmarkImage() throws {
        let label = "ETHUSDT"
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.downloadCancelled(label: label)))

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasXmark = images.contains { image in
            (try? image.actualImage().name() == "xmark.circle.fill") ?? false
        }
        #expect(hasXmark)
    }

    @MainActor
    @Test func finishedStatusDisplaysCheckmarkImage() throws {
        let message = "Build Succeeded"
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.finished(message: message, at: Date())))

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasCheckmark = images.contains { image in
            (try? image.actualImage().name() == "checkmark.circle.fill") ?? false
        }
        #expect(hasCheckmark)

        let messageText = try sut.inspect().find(text: message)
        #expect(try messageText.string() == message)
    }
}

// MARK: - Button Display Tests

struct ToolbarRunningSectionViewButtonTests {

    @MainActor
    @Test func schemaButtonDisplaysSelectSchemaWhenNoneSelected() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            datasetFiles: [],
            strategyFiles: [],
            selectedMode: .Backtest
        )
        .environment(makeStatusService(.idle))

        let selectSchemaText = try sut.inspect().find(text: "Select schema")
        #expect(try selectSchemaText.string() == "Select schema")
    }

    @MainActor
    @Test func schemaButtonDisplaysSchemaNameWhenSelected() throws {
        let schema = Schema(name: "My Strategy", strategyPath: "test.wasm")
        var document = ArgoTradingDocument()
        document.addSchema(schema)
        document.selectedSchemaId = schema.id

        let sut = ToolbarRunningSectionView(
            document: .constant(document),
            datasetFiles: [],
            strategyFiles: [],
            selectedMode: .Backtest
        )
        .environment(makeStatusService(.idle))

        let schemaNameText = try sut.inspect().find(text: "My Strategy")
        #expect(try schemaNameText.string() == "My Strategy")
    }

    @MainActor
    @Test func datasetButtonDisplaysSelectDatasetWhenNoneSelected() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            datasetFiles: [],
            strategyFiles: [],
            selectedMode: .Backtest
        )
        .environment(makeStatusService(.idle))

        let selectDatasetText = try sut.inspect().find(text: "Select dataset")
        #expect(try selectDatasetText.string() == "Select dataset")
    }

    @MainActor
    @Test func datasetButtonDisplaysFileNameWhenSelected() throws {
        var document = ArgoTradingDocument()
        document.selectedDatasetURL = URL(fileURLWithPath: "/data/BTCUSDT_1hour.parquet")

        let sut = ToolbarRunningSectionView(
            document: .constant(document),
            datasetFiles: [],
            strategyFiles: [],
            selectedMode: .Backtest
        )
        .environment(makeStatusService(.idle))

        let datasetText = try sut.inspect().find(text: "BTCUSDT_1hour")
        #expect(try datasetText.string() == "BTCUSDT_1hour")
    }
}


// MARK: - Date Formatting Tests

struct ToolbarRunningSectionViewDateTests {

    @MainActor
    @Test func finishedStatusFormatsDateAsToday() throws {
        let today = Date()
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.finished(message: "Done", at: today)))

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let hasToday = texts.contains { text in
            (try? text.string().contains("Today at")) ?? false
        }
        #expect(hasToday)
    }

    @MainActor
    @Test func errorStatusFormatsDateAsYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.error(label: "Build", errors: [], at: yesterday)))

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let hasYesterday = texts.contains { text in
            (try? text.string().contains("Yesterday at")) ?? false
        }
        #expect(hasYesterday)
    }

    @MainActor
    @Test func finishedStatusFormatsOlderDate() throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let sut = ToolbarRunningStatusBadgeView()
            .environment(makeStatusService(.finished(message: "Done", at: oldDate)))

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let hasFormattedDate = texts.contains { text in
            let str = (try? text.string()) ?? ""
            return str.contains(" at ") && !str.contains("Today") && !str.contains("Yesterday")
        }
        #expect(hasFormattedDate)
    }
}

// MARK: - Animation ID Tests

struct ToolbarRunningStatusAnimationIdTests {

    @Test func idleStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.idle
        #expect(status.animationId == "idle")
    }

    @Test func runningStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.running(label: "Test")
        #expect(status.animationId == "running-Test")
    }

    @Test func downloadingStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.downloading(label: "BTC", progress: Progress(current: 1, total: 10))
        #expect(status.animationId == "downloading-BTC")
    }

    @Test func downloadCancelledStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.downloadCancelled(label: "ETH")
        #expect(status.animationId == "downloadCancelled-ETH")
    }

    @Test func backtestingStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.backtesting(label: "Test", progress: Progress(current: 5, total: 100))
        #expect(status.animationId == "backtesting")
    }

    @Test func errorStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.error(label: "Build", errors: [], at: Date())
        #expect(status.animationId == "error")
    }

    @Test func finishedStatusHasCorrectAnimationId() {
        let status = ToolbarRunningStatus.finished(message: "Done", at: Date())
        #expect(status.animationId == "finished")
    }
}
