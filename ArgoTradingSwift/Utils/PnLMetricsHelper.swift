//
//  PnLMetricsHelper.swift
//  ArgoTradingSwift
//

import SwiftUI

enum PnLMetricsHelper {
    static let totalPnl: LocalizedStringKey = "Total Profit and Loss across all trades. Combines realized PnL from closed positions and unrealized PnL from any positions still open at the end of the period."

    static let realizedPnl: LocalizedStringKey = "Profit or loss from closed positions only — the cash actually gained or lost from trades where both entry and exit were executed."

    static let unrealizedPnl: LocalizedStringKey = "Paper profit or loss from positions still open at the end of the period, valued at the final market price. Not yet locked in and will change with price movements."

    static let buyAndHoldPnl: LocalizedStringKey = "Profit or loss from passively buying at the start and holding until the end over the same period. Used as a benchmark — if Total PnL exceeds this, the active strategy outperformed buy-and-hold."

    static let maximumProfit: LocalizedStringKey = "The largest profit earned on a single trade during the period. Highlights the best individual trade outcome."

    static let maxDrawdown: LocalizedStringKey = "The largest peak-to-trough decline in portfolio value during the period. A key measure of downside risk — shows the worst loss an investor would have had to endure."

    static let pnlPercentage: LocalizedStringKey = "Total Profit and Loss expressed as a percentage of total invested capital. Useful for comparing strategies that deploy different amounts of capital."

    static let totalInvestment: LocalizedStringKey = "Total capital deployed across all trades during the period. Represents the cumulative cost basis used by the strategy to enter positions."

    static let runTimestamp: LocalizedStringKey = "The date and time when this backtest was executed. Useful for distinguishing between multiple runs of the same strategy."

    static let tradingPairs: LocalizedStringKey = "The number of matched entry-and-exit trade pairs. A trade pair consists of an opening trade and its corresponding closing trade, and is the unit used to measure PnL and win rate."

    static let winningTrades: LocalizedStringKey = "The number of closed trade pairs that ended with a profit."

    static let losingTrades: LocalizedStringKey = "The number of closed trade pairs that ended with a loss."

    static let winRate: LocalizedStringKey = "The percentage of closed trade pairs that were profitable (Winning Trades ÷ Total Trade Pairs). A high win rate alone does not guarantee profitability — a few large losses can outweigh many small wins."

    static let tradeHoldingTime: LocalizedStringKey = "How long positions were held, measured from entry to exit. Minimum, Maximum, Average, and Median summarize the distribution across all trade pairs in the period."

    static let lifoPnl: LocalizedStringKey = "Profit or loss for this trade calculated using LIFO (Last-In, First-Out) cost basis — the closing trade is matched against the most recently opened position. Differs from average-cost PnL and is often used for tax-lot or short-term-focused accounting."
}
