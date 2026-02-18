//
//  TradingService.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2/18/26.
//

import Foundation

@Observable
class TradingService {
    var isRunning: Bool = false
    var sessions: [TradingSession] = []
    var currentSession: TradingSession?

    @MainActor
    func startTrading(
        provider: TradingProvider,
        schema: Schema,
        keychainService: KeychainService,
        toolbarStatusService: ToolbarStatusService
    ) async {
        let success = await keychainService.authenticateWithBiometrics()
        guard success else { return }

        var session = TradingSession(
            tradingProviderId: provider.id,
            providerName: provider.name,
            status: .connecting,
            startedAt: Date()
        )
        sessions.insert(session, at: 0)
        currentSession = session
        isRunning = true

        await toolbarStatusService.setStatus(.trading(label: provider.name))

        // Update session to running
        session.status = .running
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = session
    }

    @MainActor
    func stopTrading(toolbarStatusService: ToolbarStatusService) async {
        guard var session = currentSession else { return }
        session.status = .stopped
        session.stoppedAt = Date()

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        currentSession = nil
        isRunning = false

        await toolbarStatusService.setStatus(.idle)
    }
}
