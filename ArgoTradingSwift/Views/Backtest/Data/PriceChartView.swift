//
//  PriceChartView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/21/25.
//

import Charts
import SwiftUI

enum ChartType: String, CaseIterable, Identifiable {
    case line = "Line"
    case candlestick = "Candlestick"

    var id: String { rawValue }
}

struct PriceChartView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PriceChartViewModel?
    @State private var chartType: ChartType = .candlestick
    @State private var selectedIndex: Int?
    @State private var scrollPositionIndex: Int = 0
    @State private var zoomScale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Zoom configuration
    private let baseVisibleCount = 100
    private let minZoom: CGFloat = 0.1
    private let maxZoom: CGFloat = 5.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            legendView

            if let vm = viewModel {
                if vm.loadedData.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Load a dataset to view the chart")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.isLoading && vm.loadedData.isEmpty {
                    ProgressView("Loading chart data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    chartContent
                }
            } else {
                ProgressView("Initializing...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            scrollInfoView
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(minWidth: 700, minHeight: 500)
        .task {
            let vm = PriceChartViewModel(url: url, dbService: dbService)
            vm.onError = { message in
                alertManager.showAlert(message: message)
            }
            viewModel = vm
            await vm.loadInitialData()
            scrollPositionIndex = max(0, vm.sortedData.count - visibleCount)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Price Chart")
                .font(.headline)

            Spacer()

            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        zoomScale = max(minZoom, zoomScale / 1.5)
                    }
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Text("\(Int(zoomScale * 100))%")
                    .font(.caption)
                    .frame(width: 40)

                Button {
                    withAnimation {
                        zoomScale = min(maxZoom, zoomScale * 1.5)
                    }
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.borderless)

                Button {
                    withAnimation {
                        zoomScale = 1.0
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(zoomScale == 1.0)
            }

            Divider()
                .frame(height: 20)

            Picker("", selection: $chartType) {
                ForEach(ChartType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)
        }
    }

    // MARK: - Legend (shows OHLCV on hover)

    private var legendView: some View {
        Group {
            if let idx = selectedIndex,
               let item = viewModel?.priceData(at: idx)
            {
                HStack(spacing: 16) {
                    Text(item.date, format: .dateTime.month().day().hour().minute())
                        .foregroundStyle(.secondary)

                    Group {
                        LegendItem(label: "O", value: item.open, color: .primary)
                        LegendItem(label: "H", value: item.high, color: .green)
                        LegendItem(label: "L", value: item.low, color: .red)
                        LegendItem(label: "C", value: item.close, color: item.close >= item.open ? .green : .red)
                        LegendItem(label: "V", value: item.volume, color: .blue, decimals: 0)
                    }
                }
                .font(.system(.body, design: .monospaced))
            } else {
                Text("Hover over chart to see values")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 24)
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        guard let vm = viewModel else { return AnyView(EmptyView()) }

        let chart = Chart {
            ForEach(vm.indexedData) { item in
                switch chartType {
                case .line:
                    LineMark(
                        x: .value("Index", item.index),
                        y: .value("Close", item.data.close)
                    )
                    .foregroundStyle(.blue)
                case .candlestick:
                    RectangleMark(
                        x: .value("Index", item.index),
                        yStart: .value("Open", item.data.open),
                        yEnd: .value("Close", item.data.close),
                        width: .fixed(candlestickWidth)
                    )
                    .foregroundStyle(item.data.close >= item.data.open ? .green : .red)

                    RuleMark(
                        x: .value("Index", item.index),
                        yStart: .value("Low", item.data.low),
                        yEnd: .value("High", item.data.high)
                    )
                    .foregroundStyle(item.data.close >= item.data.open ? .green : .red)
                    .lineStyle(StrokeStyle(lineWidth: max(1, candlestickWidth / 6)))
                }
            }

            if let idx = selectedIndex {
                RuleMark(x: .value("Selected", idx))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .center) {
                        if let item = vm.priceData(at: idx) {
                            Text(item.close, format: .number.precision(.fractionLength(2)))
                                .font(.caption2)
                                .padding(4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
            }
        }
        .chartYScale(domain: vm.yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let idx = value.as(Int.self),
                       let item = vm.priceData(at: idx)
                    {
                        Text(item.date, format: .dateTime.month().day().hour().minute())
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(doubleValue, format: .number.precision(.fractionLength(2)))
                    }
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleCount)
        .chartScrollPosition(x: $scrollPositionIndex)
        .chartXSelection(value: $selectedIndex)
        .onChange(of: scrollPositionIndex) { _, newIndex in
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                await vm.checkAndLoadMoreData(at: newIndex, visibleCount: visibleCount)
            }
        }

        return AnyView(chart.gesture(magnificationGesture))
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .updating($magnifyBy) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                let newScale = zoomScale * value.magnification
                zoomScale = min(max(newScale, minZoom), maxZoom)
            }
    }

    // MARK: - Scroll Info

    private var scrollInfoView: some View {
        HStack {
            if let vm = viewModel, vm.isLoading {
                ProgressView()
                    .scaleEffect(0.4)
                Text("Loading more data...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let vm = viewModel {
                Text("Showing \(vm.loadedData.count) of \(vm.totalCount) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("• Scroll to navigate, pinch to zoom")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 44)
    }

    // MARK: - Computed Properties

    private var visibleCount: Int {
        let scale = max(0.01, zoomScale * magnifyBy)
        let adjustedCount = Double(baseVisibleCount) / scale
        guard adjustedCount.isFinite else { return baseVisibleCount }
        return min(max(10, Int(adjustedCount)), 200)
    }

    private var candlestickWidth: CGFloat {
        let scale = max(0.1, zoomScale * magnifyBy)
        let baseWidth: CGFloat = 6
        return max(2, min(baseWidth * scale, 20))
    }
}

// MARK: - Legend Item Component

private struct LegendItem: View {
    let label: String
    let value: Double
    let color: Color
    var decimals: Int = 2

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value, format: .number.precision(.fractionLength(decimals)))
                .foregroundStyle(color)
        }
    }
}

#Preview {
    PriceChartView(url: URL(fileURLWithPath: "/tmp/test.parquet"))
        .environment(DuckDBService())
        .environment(AlertManager())
}
