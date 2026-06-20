---
slug: architecture/services
title: Services Reference
description: Role of each @Observable service in ArgoTrading macOS
---

# Services Reference

All services live in `ArgoTradingSwift/Services/`, are marked `@Observable`,
and are injected into the SwiftUI environment from `ArgoTradingSwiftApp.swift`.
Views consume them with `@Environment(ServiceType.self)`.

## Data & persistence

| Service | Responsibility |
|---------|----------------|
| `DuckDBService` / `DuckDBServiceProtocol` | In-memory DuckDB instance for querying Parquet price-data files. Backs the paginated data viewer. |
| `DatasetService` | Catalogs Parquet datasets in the document's `dataFolder`. |
| `DatasetDownloadService` | Downloads market data via the ArgoTrading framework with progress tracking. |
| `SchemaService` | Loads, reads, and updates strategy/engine schemas. |
| `DocumentRegistry` | Tracks open documents. |
| `FolderWatcher` | File-system monitoring for project folders. |
| `KeychainService` | Secure credential storage (trading-provider secrets). |

## Strategy & backtesting

| Service | Responsibility |
|---------|----------------|
| `StrategyService` | Imports and lists compiled `.wasm` strategies. |
| `StrategyCacheService` | Caches parsed strategy metadata. |
| `BacktestService` | Runs backtests against the selected schema/dataset. |
| `BacktestResultService` | Reads and aggregates backtest result output. |
| `PriceChartViewModel` | Drives the price chart for a selected dataset. |

## Live trading

| Service | Responsibility |
|---------|----------------|
| `TradingProviderService` | Manages connections to live trading providers. |
| `TradingService` | Orchestrates the live-trading engine lifecycle; populates `currentSymbols` on engine start and wires wallet invalidation. |
| `TradingResultService` | Live trading results/orders. |
| `WalletService` | Async wallet data fetching, order-diff notifications, and order-badge state. Uses a dual-engine architecture so the wallet is reachable off market hours. |

## App infrastructure

| Service | Responsibility |
|---------|----------------|
| `NavigationService` | Holds `NavigationPath` and current `EditorMode`. |
| `AlertManager` | Centralized alert presentation. |
| `ToolbarStatusService` | Drives the toolbar running-status indicator. |
| `MCPServerService` | Hosts the embedded MCP server (see the MCP Tools reference). |
| `UpdaterDelegate` | Sparkle auto-update integration. |

## Conventions

- **One SwiftUI component per file.** Each `View` struct lives in its own
  `.swift` file under the relevant `Views/` feature folder.
- Services own side effects; views stay declarative and observe service state.
