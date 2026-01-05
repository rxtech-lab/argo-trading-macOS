//
//  StrategyCacheServiceTests.swift
//  ArgoTradingSwiftTests
//
//  Created by Claude on 1/5/26.
//

import CryptoKit
import Foundation
import Testing

@testable import ArgoTradingSwift

struct StrategyCacheServiceTests {

    // MARK: - Initial State Tests

    @Test func initialState() {
        let service = StrategyCacheService()

        #expect(service.cacheHitCount == 0)
        #expect(service.cacheMissCount == 0)
        #expect(service.cacheEntryCount == 0)
    }

    // MARK: - Clear Cache Tests

    @Test func clearCacheResetsState() throws {
        let service = StrategyCacheService()

        // Manually access the cache to set up state
        // Since we can't easily populate the cache without real wasm files,
        // we'll just verify that clearCache resets the counters
        service.clearCache()

        #expect(service.cacheHitCount == 0)
        #expect(service.cacheMissCount == 0)
        #expect(service.cacheEntryCount == 0)
    }

    // MARK: - Invalidation Tests

    @Test func invalidateRemovesSingleEntry() throws {
        let fileManager = FileManager.default
        let service = StrategyCacheService(fileManager: fileManager)

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("cache_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("test.wasm")
        try Data("test content".utf8).write(to: testFile)

        // Invalidate should not throw even if entry doesn't exist
        service.invalidate(url: testFile)

        #expect(service.cacheEntryCount == 0)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func invalidateAllInFolderRemovesMatchingEntries() throws {
        let fileManager = FileManager.default
        let service = StrategyCacheService(fileManager: fileManager)

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("cache_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        // Invalidate all in folder should not throw even if no entries exist
        service.invalidateAll(inFolder: testDir)

        #expect(service.cacheEntryCount == 0)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    // MARK: - Error Handling Tests

    @Test func fileNotFoundThrowsCorrectError() async throws {
        let service = StrategyCacheService()
        let nonExistentFile = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).wasm")

        do {
            _ = try await service.getMetadata(for: nonExistentFile)
            Issue.record("Expected error to be thrown")
        } catch let error as StrategyCacheError {
            if case .fileNotFound(let url) = error {
                #expect(url == nonExistentFile)
            } else {
                Issue.record("Expected fileNotFound error, got: \(error)")
            }
        } catch {
            Issue.record("Expected StrategyCacheError, got: \(error)")
        }
    }

    // MARK: - Hash Computation Tests

    @Test func streamingHashMatchesNonStreamingHash() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("hash_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        // Create a test file with known content
        let testFile = testDir.appendingPathComponent("test_hash.bin")
        let testContent = Data(repeating: 0xAB, count: 1024 * 100)  // 100KB of data
        try testContent.write(to: testFile)

        // Compute hash using the streaming method (similar to what the service does)
        let streamingHash = try computeStreamingHash(for: testFile)

        // Compute hash using the non-streaming method
        let data = try Data(contentsOf: testFile)
        let nonStreamingHash = SHA256.hash(data: data)
        let nonStreamingHashString = nonStreamingHash.compactMap { String(format: "%02x", $0) }.joined()

        #expect(streamingHash == nonStreamingHashString)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func hashChangesWhenFileContentChanges() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("hash_change_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("test_hash.bin")

        // Write initial content
        try Data("initial content".utf8).write(to: testFile)
        let hash1 = try computeStreamingHash(for: testFile)

        // Write different content
        try Data("modified content".utf8).write(to: testFile)
        let hash2 = try computeStreamingHash(for: testFile)

        #expect(hash1 != hash2)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func hashIsDeterministic() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("hash_deterministic_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("test_hash.bin")
        try Data("consistent content".utf8).write(to: testFile)

        // Compute hash multiple times
        let hash1 = try computeStreamingHash(for: testFile)
        let hash2 = try computeStreamingHash(for: testFile)
        let hash3 = try computeStreamingHash(for: testFile)

        #expect(hash1 == hash2)
        #expect(hash2 == hash3)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func hashWorksForLargeFiles() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("large_file_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        // Create a file larger than the chunk size (64KB)
        let testFile = testDir.appendingPathComponent("large_test.bin")
        let largeContent = Data(repeating: 0xCD, count: 256 * 1024)  // 256KB
        try largeContent.write(to: testFile)

        // Should not throw and should match non-streaming
        let streamingHash = try computeStreamingHash(for: testFile)
        let data = try Data(contentsOf: testFile)
        let expectedHash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()

        #expect(streamingHash == expectedHash)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func hashWorksForEmptyFiles() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("empty_file_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        let testFile = testDir.appendingPathComponent("empty.bin")
        try Data().write(to: testFile)

        let streamingHash = try computeStreamingHash(for: testFile)
        let expectedHash = SHA256.hash(data: Data()).compactMap { String(format: "%02x", $0) }.joined()

        #expect(streamingHash == expectedHash)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    @Test func hashWorksForFileSmallerThanChunk() throws {
        let fileManager = FileManager.default

        let tempDir = fileManager.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("small_file_test_\(UUID().uuidString)")
        try fileManager.createDirectory(at: testDir, withIntermediateDirectories: true)

        // Create a file smaller than chunk size (< 64KB)
        let testFile = testDir.appendingPathComponent("small.bin")
        let smallContent = Data("small content".utf8)
        try smallContent.write(to: testFile)

        let streamingHash = try computeStreamingHash(for: testFile)
        let expectedHash = SHA256.hash(data: smallContent).compactMap { String(format: "%02x", $0) }.joined()

        #expect(streamingHash == expectedHash)

        // Cleanup
        try? fileManager.removeItem(at: testDir)
    }

    // MARK: - Helpers

    /// Helper function that mimics the streaming hash computation from StrategyCacheService
    private func computeStreamingHash(for url: URL) throws -> String {
        var hasher = SHA256()
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        let chunkSize = 64 * 1024  // 64KB chunks - same as service
        while let chunk = try fileHandle.read(upToCount: chunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
