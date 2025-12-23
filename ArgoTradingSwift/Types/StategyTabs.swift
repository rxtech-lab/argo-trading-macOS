//
//  StategyTabs.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 12/23/25.
//

import SwiftUI

enum StrategyTab: CaseIterable, Identifiable, Hashable {
    case general
    case parameters

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general:
            return "General"
        case .parameters:
            return "Parameters"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .parameters:
            return "slider.horizontal.3"
        }
    }
}
