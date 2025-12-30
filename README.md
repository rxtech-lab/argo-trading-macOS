# ArgoTrading macOS

ArgoTrading is a document-based macOS SwiftUI app for building, backtesting, and (future) live-trading strategies. Each project is saved as a `.rxtrading` document (`UTType: lab.rxlab.argo-trading`) that tracks your data, strategies, schemas, and backtest results.

## Requirements
- macOS with Xcode installed (SwiftUI + Swift Concurrency toolchain)
- Dependencies are resolved via Swift Package Manager (automatic download in Xcode)
- DuckDB native library included with the project

## Project structure
- `ArgoTradingSwift/` – SwiftUI application code and services
- `ArgoTradingSwiftTests/` & `ArgoTradingSwiftUITests/` – unit/UI tests
- Document model (`ArgoTradingDocument`) stores:
  - `dataFolder` – market data location
  - `strategyFolder` – strategy sources
  - `resultFolder` – backtest outputs
  - Schemas & dataset selection used by the backtest runner

## Getting started
1. Open `ArgoTradingSwift.xcodeproj` in Xcode (SPM will fetch dependencies automatically).
2. Build and run to open the welcome window, create a new project, or open an existing `.rxtrading` document.

## Build & test
Run from the repository root:
```bash
xcodebuild -project ArgoTradingSwift.xcodeproj -scheme ArgoTradingSwift build
xcodebuild -project ArgoTradingSwift.xcodeproj -scheme ArgoTradingSwift test
```
Tests require a macOS environment with Xcode’s command-line tools available.
