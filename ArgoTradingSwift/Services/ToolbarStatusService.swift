//
//  ToolbarStatusViewModel.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/25/25.
//

import SwiftUI

@Observable
class ToolbarStatusService {
    /**
     Status of the toolbar's running state.
     */
    private(set) var toolbarRunningStatus: ToolbarRunningStatus = .idle

    private var lastStatusChangeTime: Date = .distantPast
    private let minimumDisplayDuration: TimeInterval = 1.0

    @MainActor
    func setStatus(_ newStatus: ToolbarRunningStatus) async {
        let elapsed = Date().timeIntervalSince(lastStatusChangeTime)
        let remaining = minimumDisplayDuration - elapsed

        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }

        toolbarRunningStatus = newStatus
        lastStatusChangeTime = Date()
    }

    /// Set status immediately without delay (for progress updates)
    func setStatusImmediately(_ newStatus: ToolbarRunningStatus) {
        toolbarRunningStatus = newStatus
        lastStatusChangeTime = Date()
    }
}
