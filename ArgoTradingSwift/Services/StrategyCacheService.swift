//
//  StrategyCacheService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/5/26.
//

import ArgoTrading
import CryptoKit
import Foundation

/// Errors that can occur during strategy metadata caching
enum StrategyCacheError: LocalizedError {
    case fileNotFound(URL)
    case hashComputationFailed(URL, Error)
    case metadataLoadFailed(URL, Error)
    case apiInitializationFailed

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Strategy file not found: \(url.lastPathComponent)"
        case .hashComputationFailed(let url, let error):
            return "Failed to compute hash for \(url.lastPathComponent): \(error.localizedDescription)"
        case .metadataLoadFailed(let url, let error):
            return "Failed to load metadata for \(url.lastPathComponent): \(error.localizedDescription)"
        case .apiInitializationFailed:
            return "Failed to initialize strategy API"
        }
    }
}

/// Cached entry containing metadata and its content hash
private struct CacheEntry {
    let metadata: SwiftargoStrategyMetadata
    let contentHash: String
    let cachedAt: Date
}

/// Service that caches strategy metadata in memory using SHA256 content hash as the cache key.
/// Cache is cleared on app restart.
@Observable
class StrategyCacheService {
    /// Cache storage: keyed by file path for quick lookup
    /// Value contains the hash to validate freshness
    private var cache: [String: CacheEntry] = [:]

    /// Number of cache hits
    private(set) var cacheHitCount: Int = 0

    /// Number of cache misses
    private(set) var cacheMissCount: Int = 0

    /// Number of entries in cache
    var cacheEntryCount: Int {
        cache.count
    }

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Get strategy metadata, using cache when available.
    /// - Parameter url: URL to the .wasm strategy file
    /// - Returns: Strategy metadata
    /// - Throws: StrategyCacheError on failure
    func getMetadata(for url: URL) async throws -> SwiftargoStrategyMetadata {
        let path = url.toPathStringWithoutFilePrefix()

        // Compute content hash
        let contentHash = try await computeContentHash(for: url)

        // Check cache - if path exists and hash matches, return cached value
        if let entry = cache[path], entry.contentHash == contentHash {
            cacheHitCount += 1
            return entry.metadata
        }

        // Cache miss - load from API
        cacheMissCount += 1
        let metadata = try await loadMetadata(from: path, url: url)

        // Store in cache
        cache[path] = CacheEntry(
            metadata: metadata,
            contentHash: contentHash,
            cachedAt: Date()
        )

        return metadata
    }

    /// Clear all cached entries
    func clearCache() {
        cache.removeAll()
        cacheHitCount = 0
        cacheMissCount = 0
    }

    /// Invalidate cache for a specific file
    func invalidate(url: URL) {
        let path = url.toPathStringWithoutFilePrefix()
        cache.removeValue(forKey: path)
    }

    /// Invalidate cache entries matching a folder path prefix
    func invalidateAll(inFolder folderURL: URL) {
        let folderPath = folderURL.toPathStringWithoutFilePrefix()
        cache = cache.filter { !$0.key.hasPrefix(folderPath) }
    }

    // MARK: - Private Helpers

    private func computeContentHash(for url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard self.fileManager.fileExists(atPath: url.path) else {
                throw StrategyCacheError.fileNotFound(url)
            }

            do {
                // Use streaming hash computation for memory efficiency
                var hasher = SHA256()
                let fileHandle = try FileHandle(forReadingFrom: url)
                defer { try? fileHandle.close() }

                let chunkSize = 64 * 1024  // 64KB chunks
                while let chunk = try fileHandle.read(upToCount: chunkSize), !chunk.isEmpty {
                    hasher.update(data: chunk)
                }

                let digest = hasher.finalize()
                return digest.compactMap { String(format: "%02x", $0) }.joined()
            } catch let error as StrategyCacheError {
                throw error
            } catch {
                throw StrategyCacheError.hashComputationFailed(url, error)
            }
        }.value
    }

    private func loadMetadata(from path: String, url: URL) async throws -> SwiftargoStrategyMetadata {
        try await Task.detached(priority: .userInitiated) {
            guard let api = SwiftargoStrategyApi() else {
                throw StrategyCacheError.apiInitializationFailed
            }

            do {
                return try api.getStrategyMetadata(path)
            } catch {
                throw StrategyCacheError.metadataLoadFailed(url, error)
            }
        }.value
    }
}
