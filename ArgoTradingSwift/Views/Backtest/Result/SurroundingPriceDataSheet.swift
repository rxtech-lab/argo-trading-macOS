//
//  SurroundingPriceDataSheet.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct SurroundingPriceDataSheet: View {
    let timestamp: Date
    let dataFilePath: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager

    @State private var priceData: [PriceData] = []
    @State private var isLoading: Bool = false
    @State private var highlightedId: String?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            tableView
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            await loadData()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(timestamp, format: .dateTime.year().month().day().hour().minute().second())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private var tableView: some View {
        Table(priceData) {
            TableColumn("Time") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text(price.date, format: .dateTime.year().month().day().hour().minute().second())
                }
            }
            .width(min: 140, ideal: 160)

            TableColumn("Open") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text("\(price.open, format: .number.precision(.fractionLength(2)))")
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("High") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text("\(price.high, format: .number.precision(.fractionLength(2)))")
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Low") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text("\(price.low, format: .number.precision(.fractionLength(2)))")
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Close") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text("\(price.close, format: .number.precision(.fractionLength(2)))")
                }
            }
            .width(min: 60, ideal: 80)

            TableColumn("Volume") { price in
                highlightedCell(isHighlighted: price.id == highlightedId) {
                    Text("\(price.volume, format: .number.precision(.fractionLength(0)))")
                }
            }
            .width(min: 80, ideal: 100)
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .padding()
                    .glassEffect()
            } else if priceData.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis")
            }
        }
    }

    @ViewBuilder
    private func highlightedCell<Content: View>(isHighlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        if isHighlighted {
            content()
                .fontWeight(.bold)
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(Color.orange.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        } else {
            content()
        }
    }
}

extension SurroundingPriceDataSheet {
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try dbService.initDatabase()
            priceData = try await dbService.fetchPriceDataAroundTimestamp(
                filePath: dataFilePath,
                timestamp: timestamp,
                count: 100
            )

            // Find the closest candle to the timestamp for highlighting
            highlightedId = findClosestCandle()?.id
        } catch {
            print("Error loading surrounding price data: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }

    private func findClosestCandle() -> PriceData? {
        guard !priceData.isEmpty else { return nil }

        return priceData.min { a, b in
            abs(a.date.timeIntervalSince(timestamp)) < abs(b.date.timeIntervalSince(timestamp))
        }
    }
}

#Preview {
    SurroundingPriceDataSheet(
        timestamp: Date(),
        dataFilePath: URL(fileURLWithPath: "/tmp/data.parquet"),
        title: "AAPL - Buy"
    )
    .environment(DuckDBService())
    .environment(AlertManager())
}
