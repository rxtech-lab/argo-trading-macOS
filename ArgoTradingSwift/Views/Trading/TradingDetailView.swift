//
//  TradingDetailView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingDetailView: View {
    var navigationService: NavigationService
    @Environment(TradingService.self) private var tradingService

    var body: some View {
        switch navigationService.tradingSelection {
        case .trading(let trading):
            switch trading {
            case .session(let id):
                if let session = tradingService.sessions.first(where: { $0.id == id }) {
                    TradingSessionDetailView(session: session)
                        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                } else {
                    ContentUnavailableView(
                        "Session Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected session could not be found")
                    )
                    .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
                }
            case nil:
                tradingEmptyState
            }
        default:
            tradingEmptyState
        }
    }

    private var tradingEmptyState: some View {
        ContentUnavailableView(
            "Trading Details",
            systemImage: "info.circle",
            description: Text("Select a trading session to view details")
        )
        .navigationSplitViewColumnWidth(min: 350, ideal: 400, max: 500)
    }
}

// MARK: - Trading Session Detail

private enum TradingSessionTab: String, CaseIterable, Identifiable {
    case general = "General"
    case trades = "Trades"
    case marks = "Marks"

    var id: String { rawValue }
}

struct TradingSessionDetailView: View {
    let session: TradingSession
    @State private var selectedTab: TradingSessionTab = .general

    var body: some View {
        VStack {
            Picker("Select Tab", selection: $selectedTab) {
                ForEach(TradingSessionTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch selectedTab {
            case .general:
                buildGeneralTab()
            case .trades:
                if let tradesFilePath = session.tradesFilePath,
                   let dataFilePath = session.dataFilePath
                {
                    TradesTableView(
                        filePath: URL(fileURLWithPath: tradesFilePath),
                        dataFilePath: URL(fileURLWithPath: dataFilePath)
                    )
                } else {
                    ContentUnavailableView(
                        "No Trades Data",
                        systemImage: "tablecells",
                        description: Text("Trade data will appear here during an active session")
                    )
                }
            case .marks:
                if let marksFilePath = session.marksFilePath,
                   let dataFilePath = session.dataFilePath
                {
                    MarksTableView(
                        filePath: URL(fileURLWithPath: marksFilePath),
                        dataFilePath: URL(fileURLWithPath: dataFilePath)
                    )
                } else {
                    ContentUnavailableView(
                        "No Marks Data",
                        systemImage: "tablecells",
                        description: Text("Mark data will appear here during an active session")
                    )
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func buildGeneralTab() -> some View {
        Form {
            Section("Session Info") {
                LabeledContent("Provider", value: session.providerName)
                LabeledContent("Status", value: session.status.title)
                if let startedAt = session.startedAt {
                    LabeledContent("Started", value: startedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let stoppedAt = session.stoppedAt {
                    LabeledContent("Stopped", value: stoppedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Performance") {
                LabeledContent("PnL", value: formatCurrency(session.pnl))
                LabeledContent("Trade Count", value: "\(session.tradeCount)")
            }
        }
        .formStyle(.grouped)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
