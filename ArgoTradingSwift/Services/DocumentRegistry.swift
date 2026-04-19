//
//  DocumentRegistry.swift
//  ArgoTradingSwift
//
//  Tracks open .rxtrading document windows so the MCP layer can resolve the
//  frontmost/key document and mutate it through its SwiftUI binding.
//

import AppKit
import Foundation
import SwiftUI

struct DocumentServices {
    let backtest: BacktestService
    let schema: SchemaService
    let strategy: StrategyService
    let dataset: DatasetService
    let toolbar: ToolbarStatusService
    let strategyCache: StrategyCacheService
    let keychain: KeychainService
    let backtestResult: BacktestResultService
}

final class DocumentHandle: @unchecked Sendable {
    let id = UUID()
    let fileURL: URL?
    private let binding: Binding<ArgoTradingDocument>
    let services: DocumentServices

    init(fileURL: URL?, binding: Binding<ArgoTradingDocument>, services: DocumentServices) {
        self.fileURL = fileURL
        self.binding = binding
        self.services = services
    }

    @MainActor
    func snapshot() -> ArgoTradingDocument {
        binding.wrappedValue
    }

    @MainActor
    func mutate(_ mutator: (inout ArgoTradingDocument) -> Void) {
        var copy = binding.wrappedValue
        mutator(&copy)
        binding.wrappedValue = copy
    }
}

final class DocumentRegistry: @unchecked Sendable {
    static let shared = DocumentRegistry()

    private let lock = NSLock()
    private var handles: [UUID: DocumentHandle] = [:]
    private var lastRegisteredID: UUID?

    private init() {}

    func register(_ handle: DocumentHandle) {
        lock.lock()
        defer { lock.unlock() }
        handles[handle.id] = handle
        lastRegisteredID = handle.id
    }

    func unregister(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        handles.removeValue(forKey: id)
        if lastRegisteredID == id {
            lastRegisteredID = handles.keys.first
        }
    }

    @MainActor
    func current() -> DocumentHandle? {
        // 1. Prefer the document bound to the current key window.
        if let keyWindow = NSApp.keyWindow ?? NSApp.mainWindow,
           let url = keyWindow.representedURL
        {
            let match: DocumentHandle? = {
                lock.lock()
                defer { lock.unlock() }
                return handles.values.first { $0.fileURL?.standardized == url.standardized }
            }()
            if let match { return match }
        }
        // 2. Fall back to NSDocumentController's current document.
        if let url = NSDocumentController.shared.currentDocument?.fileURL {
            let match: DocumentHandle? = {
                lock.lock()
                defer { lock.unlock() }
                return handles.values.first { $0.fileURL?.standardized == url.standardized }
            }()
            if let match { return match }
        }
        // 3. Fall back to the most recently registered handle (likely the only one).
        lock.lock()
        defer { lock.unlock() }
        guard let id = lastRegisteredID else { return nil }
        return handles[id]
    }
}
