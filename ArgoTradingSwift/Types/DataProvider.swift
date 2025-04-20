//
//  DataProvider.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//
import SwiftUI

enum DataProvider: String, CaseIterable, Identifiable {
    case Polygon = "polygon"
    case Binance = "binance"

    var id: String { self.rawValue }

    @ViewBuilder
    var providerField: some View {
        switch self {
        case .Polygon:
            PolygonApiKeyField()
        case .Binance:
            EmptyView()
        }
    }
}
