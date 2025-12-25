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

// MARK: - Status View Rendering Tests

struct ToolbarRunningSectionViewStatusTests {

    @MainActor
    @Test func idleStatusDisplaysIdleText() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let text = try sut.inspect().find(text: "Idle")
        #expect(try text.string() == "Idle")
    }

    @MainActor
    @Test func runningStatusDisplaysLabel() throws {
        let label = "Building..."
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .running(label: label),
            datasetFiles: [],
            strategyFiles: []
        )

        let labelText = try sut.inspect().find(text: label)
        #expect(try labelText.string() == label)
    }

    @MainActor
    @Test func downloadingStatusDisplaysDownloadingLabel() throws {
        let label = "BTCUSDT"
        let progress = Progress(current: 50, total: 100)
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .downloading(label: label, progress: progress),
            datasetFiles: [],
            strategyFiles: []
        )

        let downloadText = try sut.inspect().find(text: "Downloading \(label)")
        #expect(try downloadText.string() == "Downloading \(label)")
    }

    @MainActor
    @Test func backtestingStatusDisplaysLabelAndCounts() throws {
        let label = "Backtesting"
        let progress = Progress(current: 45, total: 100)
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .backtesting(label: label, progress: progress),
            datasetFiles: [],
            strategyFiles: []
        )

        let labelText = try sut.inspect().find(text: label)
        #expect(try labelText.string() == label)

        let currentText = try sut.inspect().find(text: "\(progress.current)")
        #expect(try currentText.string() == "\(progress.current)")

        let totalText = try sut.inspect().find(text: "\(progress.total)")
        #expect(try totalText.string() == "\(progress.total)")
    }

    @MainActor
    @Test func errorStatusDisplaysXmarkImage() throws {
        let label = "Build"
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .error(label: label, errors: ["Error"], at: Date()),
            datasetFiles: [],
            strategyFiles: []
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasXmark = images.contains { image in
            (try? image.actualImage().name() == "xmark.circle.fill") ?? false
        }
        #expect(hasXmark)
    }

    @MainActor
    @Test func downloadCancelledStatusDisplaysXmarkImage() throws {
        let label = "ETHUSDT"
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .downloadCancelled(label: label),
            datasetFiles: [],
            strategyFiles: []
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasXmark = images.contains { image in
            (try? image.actualImage().name() == "xmark.circle.fill") ?? false
        }
        #expect(hasXmark)
    }

    @MainActor
    @Test func finishedStatusDisplaysCheckmarkImage() throws {
        let message = "Build Succeeded"
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .finished(message: message, at: Date()),
            datasetFiles: [],
            strategyFiles: []
        )

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
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

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
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let schemaNameText = try sut.inspect().find(text: "My Strategy")
        #expect(try schemaNameText.string() == "My Strategy")
    }

    @MainActor
    @Test func datasetButtonDisplaysSelectDatasetWhenNoneSelected() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let selectDatasetText = try sut.inspect().find(text: "Select dataset")
        #expect(try selectDatasetText.string() == "Select dataset")
    }

    @MainActor
    @Test func datasetButtonDisplaysFileNameWhenSelected() throws {
        var document = ArgoTradingDocument()
        document.selectedDatasetURL = URL(fileURLWithPath: "/data/BTCUSDT_1hour.parquet")

        let sut = ToolbarRunningSectionView(
            document: .constant(document),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let datasetText = try sut.inspect().find(text: "BTCUSDT_1hour")
        #expect(try datasetText.string() == "BTCUSDT_1hour")
    }
}

// MARK: - Popover Tests

struct ToolbarRunningSectionViewPopoverTests {

    @MainActor
    @Test func viewContainsSchemaAndDatasetButtons() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let buttons = try sut.inspect().findAll(ViewType.Button.self)
        #expect(buttons.count >= 2)
    }

    @MainActor
    @Test func viewContainsDocumentIcon() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasDocIcon = images.contains { image in
            (try? image.actualImage().name() == "doc.text") ?? false
        }
        #expect(hasDocIcon)
    }

    @MainActor
    @Test func viewContainsCylinderIcon() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasCylinderIcon = images.contains { image in
            (try? image.actualImage().name() == "cylinder") ?? false
        }
        #expect(hasCylinderIcon)
    }

    @MainActor
    @Test func viewContainsChevronDownIcons() throws {
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .idle,
            datasetFiles: [],
            strategyFiles: []
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let chevronDownCount = images.filter { image in
            (try? image.actualImage().name() == "chevron.down") ?? false
        }.count
        #expect(chevronDownCount >= 2)
    }
}

// MARK: - Date Formatting Tests

struct ToolbarRunningSectionViewDateTests {

    @MainActor
    @Test func finishedStatusFormatsDateAsToday() throws {
        let today = Date()
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .finished(message: "Done", at: today),
            datasetFiles: [],
            strategyFiles: []
        )

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let hasToday = texts.contains { text in
            (try? text.string().contains("Today at")) ?? false
        }
        #expect(hasToday)
    }

    @MainActor
    @Test func errorStatusFormatsDateAsYesterday() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .error(label: "Build", errors: [], at: yesterday),
            datasetFiles: [],
            strategyFiles: []
        )

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        let hasYesterday = texts.contains { text in
            (try? text.string().contains("Yesterday at")) ?? false
        }
        #expect(hasYesterday)
    }

    @MainActor
    @Test func finishedStatusFormatsOlderDate() throws {
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let sut = ToolbarRunningSectionView(
            document: .constant(ArgoTradingDocument()),
            status: .finished(message: "Done", at: oldDate),
            datasetFiles: [],
            strategyFiles: []
        )

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

// MARK: - Progress Tests

struct ProgressTests {

    @Test func progressPercentageCalculatesCorrectly() {
        let progress = Progress(current: 50, total: 100)
        #expect(progress.percentage == 50.0)
    }

    @Test func progressPercentageHandlesZeroTotal() {
        let progress = Progress(current: 10, total: 0)
        #expect(progress.percentage == 0.0)
    }

    @Test func progressPercentageCalculatesPartialValues() {
        let progress = Progress(current: 1, total: 3)
        #expect(progress.percentage > 33.0 && progress.percentage < 34.0)
    }
}
