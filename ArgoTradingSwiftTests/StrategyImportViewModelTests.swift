//
//  StrategyImportViewModelTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/22/25.
//

import Testing
import Foundation
@testable import ArgoTradingSwift

struct StrategyImportViewModelTests {

    @Test func initialState() {
        let viewModel = StrategyImportViewModel()

        #expect(viewModel.showFileImporter == false)
        #expect(viewModel.error == nil)
    }

    @Test func importStrategySuccess() throws {
        let fileManager = FileManager.default
        let viewModel = StrategyImportViewModel(fileManager: fileManager)

        // Create temporary directories
        let tempDir = fileManager.temporaryDirectory
        let sourceDir = tempDir.appendingPathComponent("source_\(UUID().uuidString)")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Create a test wasm file
        let sourceFile = sourceDir.appendingPathComponent("test_strategy.wasm")
        let testData = Data("test wasm content".utf8)
        try testData.write(to: sourceFile)

        // Import the strategy
        viewModel.importStrategy(from: sourceFile, to: destDir)

        // Verify the file was copied
        let destFile = destDir.appendingPathComponent("test_strategy.wasm")
        #expect(fileManager.fileExists(atPath: destFile.path))
        #expect(viewModel.error == nil)

        // Verify content matches
        let copiedData = try Data(contentsOf: destFile)
        #expect(copiedData == testData)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyCreatesDestinationFolder() throws {
        let fileManager = FileManager.default
        let viewModel = StrategyImportViewModel(fileManager: fileManager)

        // Create temporary directories
        let tempDir = fileManager.temporaryDirectory
        let sourceDir = tempDir.appendingPathComponent("source_\(UUID().uuidString)")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        // Note: destDir is NOT created - the viewModel should create it

        // Create a test wasm file
        let sourceFile = sourceDir.appendingPathComponent("test_strategy.wasm")
        let testData = Data("test wasm content".utf8)
        try testData.write(to: sourceFile)

        // Import the strategy
        viewModel.importStrategy(from: sourceFile, to: destDir)

        // Verify the destination folder was created and file was copied
        #expect(fileManager.fileExists(atPath: destDir.path))
        let destFile = destDir.appendingPathComponent("test_strategy.wasm")
        #expect(fileManager.fileExists(atPath: destFile.path))
        #expect(viewModel.error == nil)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyOverwritesExistingFile() throws {
        let fileManager = FileManager.default
        let viewModel = StrategyImportViewModel(fileManager: fileManager)

        // Create temporary directories
        let tempDir = fileManager.temporaryDirectory
        let sourceDir = tempDir.appendingPathComponent("source_\(UUID().uuidString)")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Create a test wasm file at source
        let sourceFile = sourceDir.appendingPathComponent("test_strategy.wasm")
        let newData = Data("new wasm content".utf8)
        try newData.write(to: sourceFile)

        // Create an existing file at destination
        let destFile = destDir.appendingPathComponent("test_strategy.wasm")
        let oldData = Data("old wasm content".utf8)
        try oldData.write(to: destFile)

        // Import the strategy (should overwrite)
        viewModel.importStrategy(from: sourceFile, to: destDir)

        // Verify the file was overwritten
        let copiedData = try Data(contentsOf: destFile)
        #expect(copiedData == newData)
        #expect(viewModel.error == nil)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyFailsWithInvalidSource() {
        let viewModel = StrategyImportViewModel()

        let tempDir = FileManager.default.temporaryDirectory
        let nonExistentFile = tempDir.appendingPathComponent("non_existent_\(UUID().uuidString).wasm")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        viewModel.importStrategy(from: nonExistentFile, to: destDir)

        #expect(viewModel.error != nil)
    }

    @Test func clearError() {
        let viewModel = StrategyImportViewModel()
        viewModel.error = "Test error"

        #expect(viewModel.error != nil)

        viewModel.clearError()

        #expect(viewModel.error == nil)
    }
}
