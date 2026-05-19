//
//  WalletModels.swift
//  ArgoTradingSwift
//

import Foundation

struct WalletAsset: Codable, Identifiable, Hashable {
    let symbol: String
    let quantity: Double
    let baseCurrency: String?
    let baseCurrencyValue: Double?

    var id: String { symbol }

    enum CodingKeys: String, CodingKey {
        case symbol
        case quantity
        case baseCurrency = "base_currency"
        case baseCurrencyValue = "base_currency_value"
    }
}

struct WalletBalance: Codable, Hashable {
    let type: String
    let value: Double
    let baseCurrency: String

    enum CodingKeys: String, CodingKey {
        case type
        case value
        case baseCurrency = "base_currency"
    }
}

struct WalletOrder: Codable, Identifiable, Hashable {
    let orderID: String
    let symbol: String
    let side: String
    let quantity: Double
    let price: Double
    let timestamp: Date
    let status: String
    let positionType: String
    let executedAt: Date
    let executedQty: Double
    let executedPrice: Double
    let fee: Double
    let pnl: Double

    var id: String { orderID + executedAt.timeIntervalSince1970.description }

    private struct OrderPayload: Codable {
        let orderID: String
        let symbol: String
        let side: String
        let quantity: Double
        let price: Double
        let timestamp: Date
        let status: String
        let positionType: String

        enum CodingKeys: String, CodingKey {
            case orderID = "order_id"
            case symbol, side, quantity, price, timestamp, status
            case positionType = "position_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case order = "Order"
        case executedAt = "ExecutedAt"
        case executedQty = "ExecutedQty"
        case executedPrice = "ExecutedPrice"
        case fee = "Fee"
        case pnl = "PnL"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let order = try container.decode(OrderPayload.self, forKey: .order)
        orderID = order.orderID
        symbol = order.symbol
        side = order.side
        quantity = order.quantity
        price = order.price
        timestamp = order.timestamp
        status = order.status
        positionType = order.positionType
        executedAt = try container.decode(Date.self, forKey: .executedAt)
        executedQty = try container.decode(Double.self, forKey: .executedQty)
        executedPrice = try container.decode(Double.self, forKey: .executedPrice)
        fee = try container.decodeIfPresent(Double.self, forKey: .fee) ?? 0
        pnl = try container.decodeIfPresent(Double.self, forKey: .pnl) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let payload = OrderPayload(
            orderID: orderID,
            symbol: symbol,
            side: side,
            quantity: quantity,
            price: price,
            timestamp: timestamp,
            status: status,
            positionType: positionType
        )
        try container.encode(payload, forKey: .order)
        try container.encode(executedAt, forKey: .executedAt)
        try container.encode(executedQty, forKey: .executedQty)
        try container.encode(executedPrice, forKey: .executedPrice)
        try container.encode(fee, forKey: .fee)
        try container.encode(pnl, forKey: .pnl)
    }
}

enum WalletJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder.DateDecodingStrategy {
    /// Go's `time.Time` JSON output uses RFC3339 with fractional seconds and a
    /// timezone offset (e.g. `2026-05-19T14:00:00.123456789+08:00`). The
    /// stock `.iso8601` strategy rejects fractional seconds, so we use a
    /// custom strategy that accepts both.
    static var iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = WalletDateParser.parse(string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized RFC3339 date: \(string)"
            )
        }
    }
}

enum WalletDateParser {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ string: String) -> Date? {
        if let date = withFraction.date(from: string) { return date }
        return plain.date(from: string)
    }
}
