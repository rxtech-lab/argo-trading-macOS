//
//  Trade.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation
import LightweightChart

enum OrderSide: String, Codable, CaseIterable, Hashable {
    case buy = "BUY"
    case sell = "SELL"
}

enum OrderType: String, Codable, CaseIterable, Hashable {
    case market = "MARKET"
    case limit = "LIMIT"
}

struct Trade: Codable, Hashable, Identifiable {
    let orderId: String
    let symbol: String
    let side: OrderSide
    let quantity: Double
    let price: Double
    let timestamp: Date
    let isCompleted: Bool
    let reason: String
    let message: String
    let strategyName: String
    let executedAt: Date?
    let executedQty: Double
    let executedPrice: Double
    let commission: Double
    let pnl: Double
    let positionType: String

    var id: String { orderId }
}

// MARK: - LightweightChart Conversion

extension Trade {
    /// Convert Trade to MarkerDataJS for LightweightChart display
    func toMarkerDataJS() -> MarkerDataJS {
        let isBuy = side == .buy
        var marker = MarkerDataJS(
            time: timestamp.timeIntervalSince1970,
            position: "aboveBar",
            color: isBuy ? "#26a69a" : "#ef5350",
            shape: isBuy ? "arrowUp" : "arrowDown",
            text: isBuy ? "BUY" : "SELL",
            id: orderId,
            markerType: "trade"
        )
        marker.isBuy = isBuy
        marker.symbol = symbol
        marker.positionType = positionType
        marker.executedQty = executedQty
        marker.executedPrice = executedPrice
        marker.pnl = pnl
        marker.reason = reason
        return marker
    }
}
