//
//  StrategyServiceTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 12/22/25.
//

import Testing
import Foundation
@testable import ArgoTradingSwift

struct StrategyServiceTests {

    @Test func initialState() {
        let service = StrategyService()

        #expect(service.showFileImporter == false)
        #expect(service.error == nil)
        #expect(service.strategyFiles.isEmpty)
    }

    @Test func importStrategySuccess() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

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
        service.importStrategy(from: sourceFile, to: destDir)

        // Verify the file was copied
        let destFile = destDir.appendingPathComponent("test_strategy.wasm")
        #expect(fileManager.fileExists(atPath: destFile.path))
        #expect(service.error == nil)

        // Verify content matches
        let copiedData = try Data(contentsOf: destFile)
        #expect(copiedData == testData)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyCreatesDestinationFolder() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

        // Create temporary directories
        let tempDir = fileManager.temporaryDirectory
        let sourceDir = tempDir.appendingPathComponent("source_\(UUID().uuidString)")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        // Note: destDir is NOT created - the service should create it

        // Create a test wasm file
        let sourceFile = sourceDir.appendingPathComponent("test_strategy.wasm")
        let testData = Data("test wasm content".utf8)
        try testData.write(to: sourceFile)

        // Import the strategy
        service.importStrategy(from: sourceFile, to: destDir)

        // Verify the destination folder was created and file was copied
        #expect(fileManager.fileExists(atPath: destDir.path))
        let destFile = destDir.appendingPathComponent("test_strategy.wasm")
        #expect(fileManager.fileExists(atPath: destFile.path))
        #expect(service.error == nil)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyOverwritesExistingFile() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

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
        service.importStrategy(from: sourceFile, to: destDir)

        // Verify the file was overwritten
        let copiedData = try Data(contentsOf: destFile)
        #expect(copiedData == newData)
        #expect(service.error == nil)

        // Cleanup
        try? fileManager.removeItem(at: sourceDir)
        try? fileManager.removeItem(at: destDir)
    }

    @Test func importStrategyFailsWithInvalidSource() {
        let service = StrategyService()

        let tempDir = FileManager.default.temporaryDirectory
        let nonExistentFile = tempDir.appendingPathComponent("non_existent_\(UUID().uuidString).wasm")
        let destDir = tempDir.appendingPathComponent("dest_\(UUID().uuidString)")

        service.importStrategy(from: nonExistentFile, to: destDir)

        #expect(service.error != nil)
    }

    @Test func clearError() {
        let service = StrategyService()
        service.error = "Test error"

        #expect(service.error != nil)

        service.clearError()

        #expect(service.error == nil)
    }

    @Test func setStrategyFolderLoadsWasmFiles() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

        // Create temporary directory with wasm files
        let tempDir = fileManager.temporaryDirectory
        let strategyDir = tempDir.appendingPathComponent("strategies_\(UUID().uuidString)")
        try fileManager.createDirectory(at: strategyDir, withIntermediateDirectories: true)

        // Create test wasm files
        let file1 = strategyDir.appendingPathComponent("alpha_strategy.wasm")
        let file2 = strategyDir.appendingPathComponent("beta_strategy.wasm")
        let nonWasmFile = strategyDir.appendingPathComponent("readme.txt")

        try Data("wasm1".utf8).write(to: file1)
        try Data("wasm2".utf8).write(to: file2)
        try Data("readme".utf8).write(to: nonWasmFile)

        // Set the strategy folder
        service.setStrategyFolder(strategyDir)

        // Verify only wasm files are loaded and sorted
        #expect(service.strategyFiles.count == 2)
        #expect(service.strategyFiles[0].lastPathComponent == "alpha_strategy.wasm")
        #expect(service.strategyFiles[1].lastPathComponent == "beta_strategy.wasm")

        // Cleanup
        try? fileManager.removeItem(at: strategyDir)
    }

    @Test func setStrategyFolderToNilClearsFiles() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

        // Create temporary directory with wasm file
        let tempDir = fileManager.temporaryDirectory
        let strategyDir = tempDir.appendingPathComponent("strategies_\(UUID().uuidString)")
        try fileManager.createDirectory(at: strategyDir, withIntermediateDirectories: true)

        let file = strategyDir.appendingPathComponent("test.wasm")
        try Data("wasm".utf8).write(to: file)

        // Set folder and verify files loaded
        service.setStrategyFolder(strategyDir)
        #expect(service.strategyFiles.count == 1)

        // Set to nil and verify files cleared
        service.setStrategyFolder(nil)
        #expect(service.strategyFiles.isEmpty)

        // Cleanup
        try? fileManager.removeItem(at: strategyDir)
    }

    @Test func deleteFileRemovesFile() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

        // Create temporary directory with wasm file
        let tempDir = fileManager.temporaryDirectory
        let strategyDir = tempDir.appendingPathComponent("strategies_\(UUID().uuidString)")
        try fileManager.createDirectory(at: strategyDir, withIntermediateDirectories: true)

        let file = strategyDir.appendingPathComponent("test.wasm")
        try Data("wasm".utf8).write(to: file)

        // Verify file exists
        #expect(fileManager.fileExists(atPath: file.path))

        // Delete the file
        try service.deleteFile(file)

        // Verify file is deleted
        #expect(!fileManager.fileExists(atPath: file.path))

        // Cleanup
        try? fileManager.removeItem(at: strategyDir)
    }

    @Test func renameFileChangesFileName() throws {
        let fileManager = FileManager.default
        let service = StrategyService(fileManager: fileManager)

        // Create temporary directory with wasm file
        let tempDir = fileManager.temporaryDirectory
        let strategyDir = tempDir.appendingPathComponent("strategies_\(UUID().uuidString)")
        try fileManager.createDirectory(at: strategyDir, withIntermediateDirectories: true)

        let originalFile = strategyDir.appendingPathComponent("old_name.wasm")
        let renamedFile = strategyDir.appendingPathComponent("new_name.wasm")
        try Data("wasm".utf8).write(to: originalFile)

        // Verify original exists
        #expect(fileManager.fileExists(atPath: originalFile.path))
        #expect(!fileManager.fileExists(atPath: renamedFile.path))

        // Rename the file
        try service.renameFile(originalFile, to: "new_name")

        // Verify file is renamed
        #expect(!fileManager.fileExists(atPath: originalFile.path))
        #expect(fileManager.fileExists(atPath: renamedFile.path))

        // Cleanup
        try? fileManager.removeItem(at: strategyDir)
    }
}
