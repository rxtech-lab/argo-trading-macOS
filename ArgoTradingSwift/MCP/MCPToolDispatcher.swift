//
//  MCPToolDispatcher.swift
//  ArgoTradingSwift
//
//  Dispatches an MCP `tools/call` invocation to the appropriate handler.
//  Handlers resolve the frontmost document via DocumentRegistry and call into
//  the existing services (BacktestService, StrategyService, etc.).
//

import Foundation
import MCP

enum MCPToolDispatcher {
    static func dispatch(
        name: String,
        arguments: [String: Value]?,
        server: MCP.Server? = nil
    ) async -> CallTool.Result {
        let args = arguments ?? [:]
        do {
            switch name {
            case MCPToolName.loadStrategy:
                return try await MCPToolHandlers.loadStrategy(args: args)
            case MCPToolName.listSchemas:
                return try await MCPToolHandlers.listSchemas(args: args)
            case MCPToolName.readSchema:
                return try await MCPToolHandlers.readSchema(args: args)
            case MCPToolName.updateSchema:
                return try await MCPToolHandlers.updateSchema(args: args)
            case MCPToolName.listData:
                return try await MCPToolHandlers.listData(args: args)
            case MCPToolName.selectSchema:
                return try await MCPToolHandlers.selectSchema(args: args)
            case MCPToolName.selectData:
                return try await MCPToolHandlers.selectData(args: args)
            case MCPToolName.runBacktest:
                return try await MCPToolHandlers.runBacktest(args: args, server: server)
            case MCPToolName.getConfig:
                return try await MCPToolHandlers.getConfig(args: args)
            case MCPToolName.getBacktestStatus:
                return try await MCPToolHandlers.getBacktestStatus(args: args)
            default:
                return .errorText("Unknown tool: \(name)")
            }
        } catch let error as MCPToolError {
            return .errorText(error.message)
        } catch {
            return .errorText(error.localizedDescription)
        }
    }
}

struct MCPToolError: Error {
    let message: String
    static func missing(_ field: String) -> MCPToolError { .init(message: "Missing required argument: \(field)") }
    static func invalid(_ field: String, _ reason: String) -> MCPToolError { .init(message: "Invalid \(field): \(reason)") }
    static let noDocument = MCPToolError(message: "No document is open. Open a .rxtrading project first.")
}

extension CallTool.Result {
    static func json(_ value: Value) -> CallTool.Result {
        // Disambiguate against the throwing `<Output: Codable>` overload.
        let structured: Value? = value
        return .init(content: [], structuredContent: structured, isError: false)
    }

    static func errorText(_ s: String) -> CallTool.Result {
        // Errors have no structured representation, so keep a text block so
        // clients can surface the message.
        .init(
            content: [.text(text: s, annotations: nil, _meta: nil)],
            structuredContent: nil,
            isError: true
        )
    }
}
