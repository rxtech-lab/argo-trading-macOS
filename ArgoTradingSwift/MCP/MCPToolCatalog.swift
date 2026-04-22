//
//  MCPToolCatalog.swift
//  ArgoTradingSwift
//
//  Declares the MCP tool set — names, descriptions, and input JSON schemas —
//  returned from the `tools/list` endpoint.
//

import Foundation
import MCP

enum MCPToolName {
    static let loadStrategy = "load_strategy"
    static let listSchemas = "list_schemas"
    static let readSchema = "read_schema"
    static let updateSchema = "update_schema"
    static let listData = "list_data"
    static let selectSchema = "select_schema"
    static let selectData = "select_data"
    static let runBacktest = "run_backtest"
    static let getConfig = "get_config"
    static let getBacktestStatus = "get_backtest_status"
}

enum MCPToolCatalog {
    /// Helper to build a JSON Schema object as an MCP `Value`.
    private static func schema(
        properties: [String: Value] = [:],
        required: [String] = []
    ) -> Value {
        var obj: [String: Value] = ["type": .string("object")]
        if !properties.isEmpty {
            obj["properties"] = .object(properties)
        }
        if !required.isEmpty {
            obj["required"] = .array(required.map { .string($0) })
        }
        obj["additionalProperties"] = .bool(false)
        return .object(obj)
    }

    private static func prop(_ type: String, description: String) -> Value {
        .object(["type": .string(type), "description": .string(description)])
    }

    static let allTools: [Tool] = [
        Tool(
            name: MCPToolName.loadStrategy,
            description: "Import a compiled WebAssembly strategy into the project's strategy folder. Overwrites existing file with the same name.",
            inputSchema: schema(
                properties: [
                    "strategy_path": prop("string", description: "Absolute path to the .wasm strategy file."),
                ],
                required: ["strategy_path"]
            )
        ),
        Tool(
            name: MCPToolName.listSchemas,
            description: "List schemas in the current project, optionally filtered by name.",
            inputSchema: schema(
                properties: [
                    "limit": prop("integer", description: "Maximum number of results."),
                    "query": prop("string", description: "Optional case-insensitive substring match on schema name."),
                ],
                required: ["limit"]
            )
        ),
        Tool(
            name: MCPToolName.readSchema,
            description: "Read a schema's backtest, live trading, and strategy configs.",
            inputSchema: schema(
                properties: [
                    "schema_id": prop("string", description: "UUID of the schema returned by list_schemas."),
                ],
                required: ["schema_id"]
            )
        ),
        Tool(
            name: MCPToolName.updateSchema,
            description: "Update a schema. Any omitted config field is left untouched.",
            inputSchema: schema(
                properties: [
                    "schema_id": prop("string", description: "UUID of the schema."),
                    "backtest_config": .object(["type": .string("object"), "description": .string("Full backtest engine config JSON object.")]),
                    "live_trading_config": .object(["type": .string("object"), "description": .string("Full live trading engine config JSON object.")]),
                    "strategy_config": .object(["type": .string("object"), "description": .string("Strategy parameter JSON object.")]),
                ],
                required: ["schema_id"]
            )
        ),
        Tool(
            name: MCPToolName.listData,
            description: "List parquet datasets available in the project's data folder.",
            inputSchema: schema()
        ),
        Tool(
            name: MCPToolName.selectSchema,
            description: "Set the currently selected schema.",
            inputSchema: schema(
                properties: [
                    "schema_id": prop("string", description: "UUID of the schema to select."),
                ],
                required: ["schema_id"]
            )
        ),
        Tool(
            name: MCPToolName.selectData,
            description: "Set the currently selected dataset.",
            inputSchema: schema(
                properties: [
                    "data_id": prop("string", description: "Dataset file name (as returned by list_data)."),
                ],
                required: ["data_id"]
            )
        ),
        Tool(
            name: MCPToolName.runBacktest,
            description: "Run a backtest using the currently selected schema and dataset. Blocks until the backtest finishes and returns the result path.",
            inputSchema: schema()
        ),
        Tool(
            name: MCPToolName.getConfig,
            description: "Return the currently selected schema and dataset.",
            inputSchema: schema()
        ),
        Tool(
            name: MCPToolName.getBacktestStatus,
            description: "Return whether a backtest is currently running and its progress. Use this to recover status if run_backtest returned an error or timed out but the job may still be running.",
            inputSchema: schema()
        ),
    ]
}
