import SwiftUI

struct BacktestStartStopButton: View {
    @Binding var document: ArgoTradingDocument
    @Environment(BacktestService.self) private var backtestService
    @Environment(ToolbarStatusService.self) private var toolbarStatusService
    @Environment(StrategyCacheService.self) private var strategyCacheService
    @Environment(KeychainService.self) private var keychainService

    var body: some View {
        let isRunning = backtestService.isRunning

        Button {
            if isRunning {
                Task { await backtestService.cancel() }
            } else {
                guard let schema = document.selectedSchema,
                      let datasetURL = document.selectedDatasetURL else { return }
                Task.detached {
                    await backtestService.runBacktest(
                        schema: schema,
                        datasetURL: datasetURL,
                        strategyFolder: document.strategyFolder,
                        resultFolder: document.resultFolder,
                        toolbarStatusService: toolbarStatusService,
                        strategyCacheService: strategyCacheService,
                        keychainService: keychainService
                    )
                }
            }
        } label: {
            if isRunning {
                Label("Stop", systemImage: "square.fill")
            } else {
                Label("Start", systemImage: "play.fill")
            }
        }
        .accessibilityIdentifier(isRunning ? "argo.stopBacktest" : "argo.runBacktest")
        .disabled(!isRunning && !document.canRunBacktest)
        .keyboardShortcut("r", modifiers: .command)
        .help(isRunning ? "Stop Backtest" : "Run Backtest")
    }
}
