import SwiftUI

struct TradingStartStopButton: View {
    @Binding var document: ArgoTradingDocument
    @Environment(TradingService.self) private var tradingService
    @Environment(ToolbarStatusService.self) private var toolbarStatusService
    @Environment(KeychainService.self) private var keychainService
    @Environment(TradingResultService.self) private var tradingResultService

    var body: some View {
        let isRunning = tradingService.isRunning
        let canStart = document.selectedTradingProvider != nil && document.selectedSchema != nil

        button(isRunning: isRunning, canStart: canStart)
            .onChange(of: isRunning) { oldValue, newValue in
                if oldValue && !newValue {
                    tradingResultService.reloadResults()
                }
            }
    }

    @ViewBuilder
    private func button(isRunning: Bool, canStart: Bool) -> some View {
        Button {
            if isRunning {
                Task { await tradingService.stopTrading(toolbarStatusService: toolbarStatusService) }
            } else {
                guard let provider = document.selectedTradingProvider,
                      let schema = document.selectedSchema else { return }
                Task {
                    await tradingService.startTrading(
                        provider: provider,
                        schema: schema,
                        strategyFolder: document.strategyFolder,
                        tradingResultFolder: document.tradingResultFolder,
                        keychainService: keychainService,
                        toolbarStatusService: toolbarStatusService
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
        .disabled(!isRunning && !canStart)
        .keyboardShortcut("r", modifiers: .command)
        .help(isRunning ? "Stop Trading" : "Start Trading")
    }
}
