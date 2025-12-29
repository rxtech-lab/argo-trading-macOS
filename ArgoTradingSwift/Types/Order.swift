//
//  Order.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import Foundation
import SwiftUI

enum OrderStatus: String, Codable, CaseIterable, Hashable, Comparable {
    case pending = "PENDING"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
    case failed = "FAILED"

    static func < (lhs: OrderStatus, rhs: OrderStatus) -> Bool {
        // Define a lifecycle order for statuses
        func rank(_ status: OrderStatus) -> Int {
            switch status {
            case .pending: return 0
            case .filled: return 1
            case .cancelled: return 2
            case .rejected: return 3
            case .failed: return 4
            }
        }
        return rank(lhs) < rank(rhs)
    }

    var forgroundColor: Color {
        switch self {
        case .filled:
            return .green
        case .cancelled, .rejected, .failed:
            return .red
        case .pending:
            return .primary
        }
    }
}

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
    let status: OrderStatus

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
        case status
    }
}
