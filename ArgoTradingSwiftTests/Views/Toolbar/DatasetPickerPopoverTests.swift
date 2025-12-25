//
//  DatasetPickerPopoverTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/25/25.
//

import Testing
import SwiftUI
import ViewInspector
@testable import ArgoTradingSwift

// MARK: - View Inspection Tests

struct DatasetPickerPopoverViewTests {

    let testDatasets = [
        URL(fileURLWithPath: "/data/BTCUSDT_1hour_2024-01-01_2024-12-31.parquet"),
        URL(fileURLWithPath: "/data/ETHUSDT_4hour_2024-01-01_2024-06-30.parquet"),
        URL(fileURLWithPath: "/data/SOLUSDT_1day_2023-06-01_2024-06-01.parquet")
    ]

    @MainActor
    @Test func withDatasetsShowsScrollView() throws {
        let sut = DatasetPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true),
            datasetFiles: testDatasets
        )

        // With datasets present, ScrollView should exist (not "No datasets available")
        _ = try sut.inspect().find(ViewType.ScrollView.self)
    }

    @MainActor
    @Test func emptyDatasetListShowsNoDatasets() throws {
        let sut = DatasetPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true),
            datasetFiles: []
        )

        let noDataText = try sut.inspect().find(text: "No datasets available")
        #expect(try noDataText.string() == "No datasets available")
    }

    @MainActor
    @Test func filterTextFieldExists() throws {
        let sut = DatasetPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true),
            datasetFiles: testDatasets
        )

        // Find the TextField with placeholder "Filter"
        let textField = try sut.inspect().find(ViewType.TextField.self)
        #expect(throws: Never.self) { try textField.labelView() }
    }

    @MainActor
    @Test func filterTextFieldHasCorrectPlaceholder() throws {
        let sut = DatasetPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true),
            datasetFiles: testDatasets
        )

        let textField = try sut.inspect().find(ViewType.TextField.self)
        let label = try textField.labelView().text().string()
        #expect(label == "Filter")
    }

    @MainActor
    @Test func magnifyingGlassIconExists() throws {
        let sut = DatasetPickerPopover(
            document: .constant(ArgoTradingDocument()),
            isPresented: .constant(true),
            datasetFiles: testDatasets
        )

        let images = try sut.inspect().findAll(ViewType.Image.self)
        let hasMagnifyingGlass = images.contains { image in
            (try? image.actualImage().name() == "magnifyingglass") ?? false
        }
        #expect(hasMagnifyingGlass)
    }
}

// MARK: - Filter Logic Tests

struct DatasetPickerPopoverFilterTests {

    let testDatasets = [
        URL(fileURLWithPath: "/data/BTCUSDT_1hour.parquet"),
        URL(fileURLWithPath: "/data/ETHUSDT_4hour.parquet"),
        URL(fileURLWithPath: "/data/SOLUSDT_1day.parquet")
    ]

    @Test func filteredDatasetsReturnsAllWhenFilterEmpty() {
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "")
        #expect(filtered.count == 3)
    }

    @Test func filteredDatasetsMatchesCaseInsensitiveLowercase() {
        // Lowercase "btc" should match "BTCUSDT"
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "btc")
        #expect(filtered.count == 1)
        #expect(filtered[0].lastPathComponent.contains("BTCUSDT"))
    }

    @Test func filteredDatasetsMatchesCaseInsensitiveUppercase() {
        // Uppercase "BTC" should also match
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "BTC")
        #expect(filtered.count == 1)
        #expect(filtered[0].lastPathComponent.contains("BTCUSDT"))
    }

    @Test func filteredDatasetsReturnsEmptyWhenNoMatches() {
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "XYZ")
        #expect(filtered.isEmpty)
    }

    @Test func filteredDatasetsMatchesPartialText() {
        // "hour" should match both BTCUSDT_1hour and ETHUSDT_4hour
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "hour")
        #expect(filtered.count == 2)
    }

    @Test func filteredDatasetsMatchesAllWithCommonPattern() {
        // "USDT" should match all 3
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "USDT")
        #expect(filtered.count == 3)
    }

    @Test func filteredDatasetsMatchesTimeframe() {
        // "day" should match only SOLUSDT_1day
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "day")
        #expect(filtered.count == 1)
        #expect(filtered[0].lastPathComponent.contains("SOLUSDT"))
    }

    @Test func filteredDatasetsIgnoresExtension() {
        // Filter should not match file extension (it's removed before matching)
        let filtered = DatasetPickerPopover.filterDatasets(testDatasets, with: "parquet")
        #expect(filtered.isEmpty)
    }
}
