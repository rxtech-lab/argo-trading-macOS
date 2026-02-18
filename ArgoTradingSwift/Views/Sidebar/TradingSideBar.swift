//
//  TradingSideBar.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

struct TradingSideBar: View {
    @Binding var document: ArgoTradingDocument
    @Bindable var navigationService: NavigationService
    @Environment(TradingService.self) private var tradingService

    var body: some View {
        List(selection: $navigationService.tradingSelection) {
            Section("Sessions") {
                if tradingService.sessions.isEmpty {
                    Text("No trading sessions")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(tradingService.sessions) { session in
                        NavigationLink(value: NavigationPath.trading(trading: .session(id: session.id))) {
                            TradingSessionRow(session: session)
                        }
                    }
                }
            }
        }
    }
}
