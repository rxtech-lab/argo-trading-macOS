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
    var toolbarRunningStatus: ToolbarRunningStatus = .idle
}
