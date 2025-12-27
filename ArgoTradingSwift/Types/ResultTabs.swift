//
//  ResultTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/27/25.
//

import SwiftUI

enum ResultTab: String, CaseIterable, Identifiable {
    case general = "General"
    case trades = "Trades"

    var id: String { self.rawValue }
}
