//
//  MonthlyBarChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 2026-04-21.
//

import Charts
import SwiftUI

struct CategoryChartPoint: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let value: Double
    let displayValue: String
}

struct GroupedChartPoint: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let series: String
    let value: Double
    let displayValue: String
}

struct CategoryLineChartView: View {
    let title: LocalizedStringKey
    let points: [CategoryChartPoint]
    let lineColor: Color
    let xAxisLabel: String
    let maxVisibleCategories: Int

    @State private var selectedCategory: String?

    init(
        title: LocalizedStringKey,
        points: [CategoryChartPoint],
        lineColor: Color = .accentColor,
        xAxisLabel: String = "Category",
        maxVisibleCategories: Int = 6
    ) {
        self.title = title
        self.points = points
        self.lineColor = lineColor
        self.xAxisLabel = xAxisLabel
        self.maxVisibleCategories = maxVisibleCategories
    }

    private var shouldScroll: Bool {
        points.count > maxVisibleCategories
    }

    private var visibleCount: Int {
        min(points.count, maxVisibleCategories)
    }

    private var selectedPoint: CategoryChartPoint? {
        guard let selectedCategory else { return nil }
        return points.first { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let point = selectedPoint {
                    HStack(spacing: 6) {
                        Text(point.category)
                            .foregroundStyle(.secondary)
                        Text(point.displayValue)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.callout)
                }
            }

            Chart(points) { point in
                LineMark(
                    x: .value(xAxisLabel, point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value(xAxisLabel, point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(selectedCategory == point.category ? 100 : 40)
            }
            .chartXSelection(value: $selectedCategory)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartScrollableAxes(shouldScroll ? .horizontal : [])
            .chartXVisibleDomain(length: visibleCount)
            .chartOverlay { proxy in
                ChartTooltipOverlay(
                    proxy: proxy,
                    selectedCategory: selectedCategory,
                    point: selectedPoint
                )
            }
            .frame(height: 200)
        }
    }
}

struct GroupedBarChartView: View {
    let title: LocalizedStringKey
    let points: [GroupedChartPoint]
    let seriesOrder: [String]
    let seriesColors: [String: Color]
    let xAxisLabel: String
    let maxVisibleCategories: Int

    @State private var selectedCategory: String?

    init(
        title: LocalizedStringKey,
        points: [GroupedChartPoint],
        seriesOrder: [String],
        seriesColors: [String: Color],
        xAxisLabel: String = "Category",
        maxVisibleCategories: Int = 6
    ) {
        self.title = title
        self.points = points
        self.seriesOrder = seriesOrder
        self.seriesColors = seriesColors
        self.xAxisLabel = xAxisLabel
        self.maxVisibleCategories = maxVisibleCategories
    }

    private var categories: [String] {
        var seen = Set<String>()
        return points.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    private var shouldScroll: Bool {
        categories.count > maxVisibleCategories
    }

    private var visibleCount: Int {
        min(categories.count, maxVisibleCategories)
    }

    private var selectedPoints: [GroupedChartPoint] {
        guard let selectedCategory else { return [] }
        let bucket = points.filter { $0.category == selectedCategory }
        return seriesOrder.compactMap { name in bucket.first(where: { $0.series == name }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    ForEach(seriesOrder, id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(seriesColors[name] ?? .accentColor)
                                .frame(width: 8, height: 8)
                            Text(LocalizedStringKey(name))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Chart(points) { point in
                BarMark(
                    x: .value(xAxisLabel, point.category),
                    y: .value("Value", point.value)
                )
                .position(by: .value("Series", point.series))
                .foregroundStyle(seriesColors[point.series] ?? .accentColor)
                .opacity(selectedCategory == nil || selectedCategory == point.category ? 1.0 : 0.4)
            }
            .chartForegroundStyleScale(
                domain: seriesOrder,
                range: seriesOrder.map { seriesColors[$0] ?? .accentColor }
            )
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedCategory)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartScrollableAxes(shouldScroll ? .horizontal : [])
            .chartXVisibleDomain(length: visibleCount)
            .chartOverlay { proxy in
                ChartGroupedTooltipOverlay(
                    proxy: proxy,
                    selectedCategory: selectedCategory,
                    points: selectedPoints,
                    seriesColors: seriesColors
                )
            }
            .frame(height: 200)
        }
    }
}

struct CategoryBarChartView: View {
    let title: LocalizedStringKey
    let points: [CategoryChartPoint]
    let positiveColor: Color
    let negativeColor: Color?
    let xAxisLabel: String
    let maxVisibleCategories: Int

    @State private var selectedCategory: String?

    init(
        title: LocalizedStringKey,
        points: [CategoryChartPoint],
        positiveColor: Color = .accentColor,
        negativeColor: Color? = nil,
        xAxisLabel: String = "Category",
        maxVisibleCategories: Int = 6
    ) {
        self.title = title
        self.points = points
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.xAxisLabel = xAxisLabel
        self.maxVisibleCategories = maxVisibleCategories
    }

    private var shouldScroll: Bool {
        points.count > maxVisibleCategories
    }

    private var visibleCount: Int {
        min(points.count, maxVisibleCategories)
    }

    private var selectedPoint: CategoryChartPoint? {
        guard let selectedCategory else { return nil }
        return points.first { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let point = selectedPoint {
                    HStack(spacing: 6) {
                        Text(point.category)
                            .foregroundStyle(.secondary)
                        Text(point.displayValue)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.callout)
                }
            }

            Chart(points) { point in
                BarMark(
                    x: .value(xAxisLabel, point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(barColor(for: point))
                .opacity(selectedCategory == nil || selectedCategory == point.category ? 1.0 : 0.4)
            }
            .chartXSelection(value: $selectedCategory)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartScrollableAxes(shouldScroll ? .horizontal : [])
            .chartXVisibleDomain(length: visibleCount)
            .chartOverlay { proxy in
                ChartTooltipOverlay(
                    proxy: proxy,
                    selectedCategory: selectedCategory,
                    point: selectedPoint
                )
            }
            .frame(height: 200)
        }
    }

    private func barColor(for point: CategoryChartPoint) -> Color {
        if let negativeColor, point.value < 0 {
            return negativeColor
        }
        return positiveColor
    }
}

private struct ChartTooltipOverlay: View {
    let proxy: ChartProxy
    let selectedCategory: String?
    let point: CategoryChartPoint?

    var body: some View {
        GeometryReader { geo in
            if let selectedCategory,
               let point,
               let plotFrame = proxy.plotFrame,
               let xPos = proxy.position(forX: selectedCategory)
            {
                let frame = geo[plotFrame]
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(point.displayValue)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.1))
                )
                .shadow(radius: 3)
                .fixedSize()
                .position(
                    x: min(max(frame.minX + xPos, frame.minX + 50), frame.maxX - 50),
                    y: frame.minY + 24
                )
            }
        }
    }
}

private struct ChartGroupedTooltipOverlay: View {
    let proxy: ChartProxy
    let selectedCategory: String?
    let points: [GroupedChartPoint]
    let seriesColors: [String: Color]

    var body: some View {
        GeometryReader { geo in
            if let selectedCategory,
               !points.isEmpty,
               let plotFrame = proxy.plotFrame,
               let xPos = proxy.position(forX: selectedCategory)
            {
                let frame = geo[plotFrame]
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedCategory)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(points) { point in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(seriesColors[point.series] ?? .accentColor)
                                .frame(width: 6, height: 6)
                            Text(LocalizedStringKey(point.series))
                                .foregroundStyle(.secondary)
                            Text(point.displayValue)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.1))
                )
                .shadow(radius: 3)
                .fixedSize()
                .position(
                    x: min(max(frame.minX + xPos, frame.minX + 70), frame.maxX - 70),
                    y: frame.minY + 30
                )
            }
        }
    }
}
