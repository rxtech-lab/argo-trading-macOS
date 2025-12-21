# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

Build and run the app using Xcode:
```bash
xcodebuild -project ArgoTradingSwift.xcodeproj -scheme ArgoTradingSwift build
```

Run tests:
```bash
xcodebuild -project ArgoTradingSwift.xcodeproj -scheme ArgoTradingSwift test
```

## Architecture Overview

ArgoTradingSwift is a **document-based macOS SwiftUI application** for trading strategy backtesting and live trading. Documents use the `.rxtrading` extension (UTType: `lab.rxlab.argo-trading`).

### Core Architecture Pattern

The app uses **@Observable services injected via SwiftUI environment**:
- Services are instantiated in `ArgoTradingSwiftApp.swift` and passed down via `.environment()`
- Views access services with `@Environment(ServiceType.self)`
- Document state flows via `@Binding var document: ArgoTradingDocument`

### Key Services (in Services/)

| Service | Purpose |
|---------|---------|
| `DuckDBService` | In-memory DuckDB database for querying Parquet price data files |
| `DatasetDownloadService` | Market data downloads via ArgoTrading framework with progress tracking |
| `AlertManager` | Centralized alert presentation |
| `NavigationService` | Navigation state (holds `NavigationPath` and `EditorMode`) |
| `FolderWatcher` | File system monitoring |

### External Dependencies

- **ArgoTrading.xcframework** - Trading operations framework (linked from `../../argo-trading/pkg/swift-argo/`)
- **DuckDB** - Swift Package for embedded analytics database
- **libduckdb.dylib** - Native library in `libs/` folder

### Document Model

`ArgoTradingDocument` stores three folder URLs:
- `dataFolder` - Market data location
- `strategyFolder` - Trading strategies
- `resultFolder` - Backtest results

### View Structure

Views are organized by feature under `Views/`:
- `NewDocument/` - Project creation wizard flow
- `DatasetDownload/` - Market data download UI
- `Backtest/Data/` - Price data viewer with pagination
- `Sidebar/` - Navigation sidebar components

**Convention:** One SwiftUI component per file. Each View struct should be in its own `.swift` file.

### Editor Modes

The app supports two modes via `EditorMode` enum:
- **Backtest** - Historical strategy testing
- **Live** - Real-time trading (not fully implemented)

Navigation within Backtest mode uses `BacktestSelection`: strategy, data (with URL), or results.
