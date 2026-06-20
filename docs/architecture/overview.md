---
slug: architecture/overview
title: Architecture Overview
description: High-level design of the ArgoTrading macOS app — document model, services, and view layer
---

# Architecture Overview

ArgoTrading macOS (target name `ArgoTradingSwift`) is a **document-based macOS
SwiftUI application** for building, backtesting, and live-trading algorithmic
trading strategies. Each project is persisted as a `.rxtrading` document
(`UTType: lab.rxlab.argo-trading`).

## Core pattern: @Observable services via the SwiftUI environment

The app is built around a set of `@Observable` service objects:

- Services are instantiated once in `ArgoTradingSwiftApp.swift` and injected
  into the view tree with `.environment()`.
- Views read them with `@Environment(ServiceType.self)`.
- Document state flows through views as `@Binding var document: ArgoTradingDocument`.

This keeps view code declarative — views observe service state and re-render,
while services own all side effects (database queries, downloads, engine
lifecycle).

## Document model

`ArgoTradingDocument` (in `Types/ArgoTradingDocument.swift`) is the persisted
unit of work. It stores three folder URLs plus the project's schemas and
dataset selection:

| Field            | Purpose                          |
|------------------|----------------------------------|
| `dataFolder`     | Market data (Parquet) location   |
| `strategyFolder` | Compiled `.wasm` trading strategies |
| `resultFolder`   | Backtest result output           |

## Editor modes

The app operates in one of two modes, modeled by the `EditorMode` enum:

- **Backtest** — historical strategy testing against committed datasets.
  Navigation uses `BacktestSelection` (strategy, data with URL, or results).
- **Live** — real-time trading via a connected trading provider, including the
  wallet window UI.

## External dependencies

- **ArgoTrading.xcframework** — the core trading/engine framework (Go core
  bridged to Swift), providing backtest and live-trading engines, dataset
  download, and the wallet API.
- **DuckDB** (Swift package + `libduckdb.dylib`) — embedded analytics database
  used to query Parquet price data.
- **LightweightChart** (local SPM package under `packages/`) — TradingView
  Lightweight Charts wrapped for SwiftUI.
- **MCP** (Model Context Protocol) — the app embeds an MCP server so external
  AI agents can drive strategy iteration. See the
  [MCP Tools reference](slug:api/mcp-tools).

## Layered structure

```
ArgoTradingSwift/
├── ArgoTradingSwiftApp.swift   # App entry, service wiring, window scenes
├── HomeView.swift              # Root window content
├── Types/                      # Document model + value types (Order, Trade, …)
├── Models/                     # Domain models (Schema, Wallet, results)
├── Services/                   # @Observable services (see Services reference)
├── MCP/                        # Embedded MCP server: catalog + dispatcher + handlers
├── Views/                      # Feature-grouped SwiftUI views
└── Commands/                   # macOS menu commands
```

See the [Services reference](slug:architecture/services) for the role of each
service.
