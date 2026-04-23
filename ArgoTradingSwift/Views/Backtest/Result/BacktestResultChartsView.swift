//
//  BacktestResultChartsView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2026-04-21.
//

import SwiftUI

struct BacktestResultChartsView: View {
    let result: BacktestResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let percentiles = result.tradePnl.percentiles {
                    chartGroup(title: "PnL Percentiles") {
                        CategoryBarChartView(
                            title: "PnL Distribution",
                            points: percentilePoints(percentiles, formatter: formatCurrency),
                            positiveColor: .green,
                            negativeColor: .red,
                            xAxisLabel: "Percentile"
                        )
                    }
                }

                if let percentiles = result.tradeHoldingTime.percentiles {
                    chartGroup(title: "Holding Time Percentiles") {
                        CategoryBarChartView(
                            title: "Holding Time Distribution",
                            points: percentilePoints(percentiles, formatter: DurationFormatter.format),
                            xAxisLabel: "Percentile"
                        )
                    }
                }

                if let monthlyTrades = result.monthlyTrades, !monthlyTrades.isEmpty {
                    chartGroup(title: "Trades Over Months") {
                        CategoryBarChartView(
                            title: "Number of Trades",
                            points: monthlyTrades.map {
                                CategoryChartPoint(
                                    category: $0.month,
                                    value: Double($0.numberOfTrades),
                                    displayValue: "\($0.numberOfTrades)"
                                )
                            },
                            xAxisLabel: "Month"
                        )
                        GroupedBarChartView(
                            title: "Winning vs Losing Trades",
                            points: monthlyTrades.flatMap { trade -> [GroupedChartPoint] in
                                [
                                    GroupedChartPoint(
                                        category: trade.month,
                                        series: "Winning",
                                        value: Double(trade.numberOfWinningTrades),
                                        displayValue: "\(trade.numberOfWinningTrades)"
                                    ),
                                    GroupedChartPoint(
                                        category: trade.month,
                                        series: "Losing",
                                        value: Double(trade.numberOfLosingTrades),
                                        displayValue: "\(trade.numberOfLosingTrades)"
                                    ),
                                ]
                            },
                            seriesOrder: ["Winning", "Losing"],
                            seriesColors: ["Winning": .green, "Losing": .red],
                            xAxisLabel: "Month"
                        )
                    }
                }

                if let monthlyBalance = result.monthlyBalance, !monthlyBalance.isEmpty {
                    chartGroup(title: "Balance Over Months") {
                        CategoryLineChartView(
                            title: "Ending Balance",
                            points: monthlyBalance.map {
                                CategoryChartPoint(
                                    category: $0.month,
                                    value: $0.endingBalance,
                                    displayValue: formatCurrency($0.endingBalance)
                                )
                            },
                            xAxisLabel: "Month"
                        )
                        CategoryBarChartView(
                            title: "Monthly Change",
                            points: monthlyBalance.map {
                                CategoryChartPoint(
                                    category: $0.month,
                                    value: $0.change,
                                    displayValue: formatCurrency($0.change)
                                )
                            },
                            positiveColor: .green,
                            negativeColor: .red,
                            xAxisLabel: "Month"
                        )
                        CategoryBarChartView(
                            title: "Realized PnL",
                            points: monthlyBalance.map {
                                CategoryChartPoint(
                                    category: $0.month,
                                    value: $0.realizedPnl,
                                    displayValue: formatCurrency($0.realizedPnl)
                                )
                            },
                            positiveColor: .green,
                            negativeColor: .red,
                            xAxisLabel: "Month"
                        )
                    }
                }

                if let monthlyHolding = result.monthlyHoldingTime, !monthlyHolding.isEmpty {
                    chartGroup(title: "Holding Time Over Months") {
                        GroupedBarChartView(
                            title: "Holding Time",
                            points: monthlyHolding.flatMap { month -> [GroupedChartPoint] in
                                [
                                    GroupedChartPoint(
                                        category: month.month,
                                        series: "Min",
                                        value: month.min,
                                        displayValue: DurationFormatter.format(month.min)
                                    ),
                                    GroupedChartPoint(
                                        category: month.month,
                                        series: "Avg",
                                        value: month.avg,
                                        displayValue: DurationFormatter.format(month.avg)
                                    ),
                                    GroupedChartPoint(
                                        category: month.month,
                                        series: "Max",
                                        value: month.max,
                                        displayValue: DurationFormatter.format(month.max)
                                    ),
                                ]
                            },
                            seriesOrder: ["Min", "Avg", "Max"],
                            seriesColors: ["Min": .blue, "Avg": .orange, "Max": .red],
                            xAxisLabel: "Month"
                        )
                    }
                }

                if !hasAnyChartData {
                    ContentUnavailableView(
                        "No Chart Data",
                        systemImage: "chart.bar",
                        description: Text("This result does not contain monthly statistics or percentile data.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding()
        }
    }

    private var hasAnyChartData: Bool {
        result.tradePnl.percentiles != nil
            || result.tradeHoldingTime.percentiles != nil
            || (result.monthlyTrades?.isEmpty == false)
            || (result.monthlyBalance?.isEmpty == false)
            || (result.monthlyHoldingTime?.isEmpty == false)
    }

    @ViewBuilder
    private func chartGroup<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func percentilePoints(
        _ percentiles: Percentiles,
        formatter: (Double) -> String
    ) -> [CategoryChartPoint] {
        [
            ("p25", percentiles.p25),
            ("p50", percentiles.p50),
            ("p75", percentiles.p75),
            ("p90", percentiles.p90),
            ("p95", percentiles.p95),
            ("p99", percentiles.p99),
        ].map { label, value in
            CategoryChartPoint(category: label, value: value, displayValue: formatter(value))
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
