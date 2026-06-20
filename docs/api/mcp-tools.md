---
slug: api/mcp-tools
title: MCP Tools Reference
description: The embedded Model Context Protocol server tools that let AI agents drive strategy iteration
---

# MCP Tools Reference

ArgoTrading macOS embeds a **Model Context Protocol (MCP) server**
(`MCPServerService`) so external AI agents can iterate on trading strategies
without driving the UI. The tool set is declared in
`MCP/MCPToolCatalog.swift`, dispatched by `MCP/MCPToolDispatcher.swift`, and
implemented in `MCP/MCPToolHandlers.swift`.

All tools operate against the **currently open project document** and its
selected schema/dataset.

## Strategy management

### `load_strategy`
Import a compiled WebAssembly strategy into the project's strategy folder.
Overwrites an existing file with the same name.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `strategy_path` | string | yes | Absolute path to the `.wasm` strategy file. |

### `list_strategies`
List compiled `.wasm` strategies in the strategy folder. Each entry includes
the strategy `id` (used by `list_strategy_results`) and its metadata name.

### `list_strategy_results`
List historical backtest results for a strategy, newest first. Each entry
includes win rate, winning/losing trade counts, max drawdown, total/realized/
unrealized PnL, max profit/loss, fees, buy-and-hold PnL, and — when available —
trading pairs, sharpe ratio, median PnL, total investment, PnL percentage, and
initial/final balance.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `strategy_id` | string | yes | Strategy identifier (from `list_strategies`). |
| `limit` | integer | no | Max results (default: all). |

## Schemas

### `list_schemas`
List schemas in the current project, optionally filtered by name.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `limit` | integer | yes | Maximum number of results. |
| `query` | string | no | Case-insensitive substring match on schema name. |

### `read_schema`
Read a schema's backtest, live-trading, and strategy configs.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_id` | string | yes | UUID returned by `list_schemas`. |

### `update_schema`
Update a schema. Any omitted config field is left untouched.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_id` | string | yes | UUID of the schema. |
| `backtest_config` | object | no | Full backtest engine config JSON object. |
| `live_trading_config` | object | no | Full live-trading engine config JSON object. |
| `strategy_config` | object | no | Strategy parameter JSON object. |

## Datasets & selection

### `list_data`
List Parquet datasets available in the project's data folder.

### `select_schema`
Set the currently selected schema.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_id` | string | yes | UUID of the schema to select. |

### `select_data`
Set the currently selected dataset.

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `data_id` | string | yes | Dataset file name (as returned by `list_data`). |

### `get_config`
Return the currently selected schema and dataset.

## Backtesting

### `run_backtest`
Run a backtest using the currently selected schema and dataset. **Blocks** until
the backtest finishes and returns the result path. Takes no parameters.

### `get_backtest_status`
Return whether a backtest is currently running and its progress. Use this to
recover status if `run_backtest` returned an error or timed out but the job may
still be running. Includes live throughput (`bars_per_second`) and realized PnL
(`realized_pnl`) while a backtest is in progress.

## Typical agent loop

1. `load_strategy` — import the compiled `.wasm`.
2. `list_schemas` / `list_data` → `select_schema` / `select_data`.
3. `run_backtest` — wait for the result path.
4. `list_strategy_results` — read stats and compare against buy-and-hold.

See the [Agent Skills guide](slug:guides/agent-skills) for the full iteration
workflow and result-analysis recipe.
