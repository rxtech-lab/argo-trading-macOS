//
//  Trade.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation

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
