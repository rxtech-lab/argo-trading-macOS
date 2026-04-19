# ArgoTradingSwift — Agent Skills

This document tells an AI agent how to iterate on a trading strategy inside ArgoTradingSwift via the embedded MCP server.

## Workflow

1. Write the strategy in Go. Framework API reference: https://rxtech-lab.github.io/argo-trading/
2. Build it: `make build` in your strategy repo produces a `.wasm` file.
3. Import it into the app with the `load_strategy` MCP tool (overwrites any previous file with the same name).
4. Pick the schema and dataset you want to run with (`select_schema`, `select_data`). Use `list_schemas` / `list_data` to discover IDs.
5. Run the backtest with `run_backtest`. The tool blocks until the run completes and returns the `result_path`.
6. Read `result_path/stats.yaml` for the summary. Per-trade detail is in the parquet file under the same run folder — load it from Python with DuckDB.

## Iteration rules

- **Keep the strategy name stable across edits.** Don't rename mid-experiment; it breaks result comparisons.
- **Before rewriting a profitable strategy, back up the `.wasm` file** (copy it out of the project strategy folder). If the new version regresses, you'll want the old one.
- **The goal is to beat buy-and-hold** on the chosen dataset, not just to be green. `stats.yaml` reports both.
- **Always analyze results with a Python script**, not by eyeballing the chart. Agents don't see the chart — they see text.

## Analyzing results with Python + DuckDB

```python
import duckdb
import yaml

run = "<result_path returned by run_backtest>"

with open(f"{run}/stats.yaml") as f:
    stats = yaml.safe_load(f)
print(stats)

# The per-trade parquet lives alongside stats.yaml — name varies by dataset.
con = duckdb.connect()
trades = con.execute(f"SELECT * FROM '{run}/*.parquet'").df()
print(trades.head())
print(trades["pnl"].describe())
```

Inspect `pnl` and `timestamp` to figure out why the strategy entered/exited at each point. Cross-reference with the dataset parquet under the project's `data/` folder for market context.

## MCP tool cheat-sheet

| Tool             | Inputs                                                         | Returns                                                   |
|------------------|----------------------------------------------------------------|-----------------------------------------------------------|
| `load_strategy`  | `strategy_path` (absolute `.wasm` path)                        | `{status, destination}` or `{isError}`                    |
| `list_schemas`   | `limit` (int), `query?` (string)                               | `{schemas: [{id, name, created_at}], total}`              |
| `read_schema`    | `schema_id` (UUID)                                             | `{id, name, strategy_path, backtest_config, live_trading_config, strategy_config}` |
| `update_schema`  | `schema_id`, `backtest_config?`, `live_trading_config?`, `strategy_config?` | `{status, schema_id}`                       |
| `list_data`      | —                                                              | `{datasets: [{id, name, ticker, start, end, timespan}]}`  |
| `select_schema`  | `schema_id` (UUID)                                             | `{status, schema_id}`                                     |
| `select_data`    | `data_id` (filename)                                           | `{status, data_id}`                                       |
| `run_backtest`   | —                                                              | `{status, result_path}` (blocking, up to 5 min)           |
| `get_config`     | —                                                              | `{selected_schema, selected_dataset}` (either may be null)|

All tools require a `.rxtrading` document to be open. The server always targets the frontmost document window.

## Server endpoint

Default: `http://127.0.0.1:33321` (probes upward if the port is taken). Change or stop the server from **Settings → MCP**. Transport is Streamable HTTP JSON-RPC 2.0 — send `POST /` with:

```
Content-Type: application/json
Accept: application/json
```
