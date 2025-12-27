//
//  Order.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation

struct Order: Codable, Hashable, Identifiable {
    let orderId: String
    let symbol: String
    let orderType: String
    let quantity: Double
    let price: Double
    let timestamp: Date
    let isCompleted: Bool
    let reason: String
    let message: String
    let strategyName: String
    let positionType: String

    var id: String { orderId }

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case symbol
        case orderType = "order_type"
        case quantity
        case price
        case timestamp
        case isCompleted = "is_completed"
        case reason
        case message
        case strategyName = "strategy_name"
        case positionType = "position_type"
    }
}
