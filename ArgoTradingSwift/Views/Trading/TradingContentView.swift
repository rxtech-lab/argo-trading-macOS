//
//  TradingContentView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingContentView: View {
    var navigationService: NavigationService
    @Environment(TradingService.self) private var tradingService

    var body: some View {
        switch navigationService.tradingSelection {
        case .trading(let trading):
            switch trading {
            case .session(let id):
                if let session = tradingService.sessions.first(where: { $0.id == id }) {
                    if let dataFilePath = session.dataFilePath {
                        ChartContentView(url: URL(fileURLWithPath: dataFilePath))
                            .id(session.id)
                            .frame(minWidth: 400)
                    } else if session.status == .connecting || session.status == .prefetching {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Connecting to \(session.providerName)...")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView(
                            "No Data Available",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Trading data will appear here once the session starts receiving data")
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "Session Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The selected session could not be found")
                    )
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
            "No Session Selected",
            systemImage: "chart.line.uptrend.xyaxis",
            description: Text("Select a trading session from the sidebar or start a new one")
        )
    }
}
