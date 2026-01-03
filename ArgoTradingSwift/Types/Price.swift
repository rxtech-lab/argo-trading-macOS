//
//  Price.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//
import Foundation

struct PriceData: Codable, Hashable, Identifiable {
    let globalIndex: Int
    let date: Date
    let ticker: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    var id: Int { globalIndex }
}
