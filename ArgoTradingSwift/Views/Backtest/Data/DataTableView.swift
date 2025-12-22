//
//  DataTableView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/22/25.
//

import SwiftUI

struct DataTableView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager

    @State private var data: PaginationResult<PriceData> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<String> = []
    @State private var showInfo = false
    @State private var sortOrder: [KeyPathComparator<PriceData>] = [KeyPathComparator(\.date, order: .reverse)]
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Price Data")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Table
            Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
                TableColumn("Date", value: \.date) { price in
                    Text(price.date, format: .dateTime.month().day().hour().minute().second())
                }
                .width(min: 100, ideal: 120)

                TableColumn("O", value: \.open) { price in
                    Text("\(price.open, format: .number.precision(.fractionLength(2)))")
                }
                .width(min: 50, ideal: 60)

                TableColumn("H", value: \.high) { price in
                    Text("\(price.high, format: .number.precision(.fractionLength(2)))")
                }
                .width(min: 50, ideal: 60)

                TableColumn("L", value: \.low) { price in
                    Text("\(price.low, format: .number.precision(.fractionLength(2)))")
                }
                .width(min: 50, ideal: 60)

                TableColumn("C", value: \.close) { price in
                    Text("\(price.close, format: .number.precision(.fractionLength(2)))")
                }
                .width(min: 50, ideal: 60)

                TableColumn("Vol", value: \.volume) { price in
                    Text("\(price.volume, format: .number.notation(.compactName))")
                }
                .width(min: 50, ideal: 60)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .padding()
                        .glassEffect()
                }
            }

            Divider()

            // Bottom bar with pagination
            HStack {
                Button {
                    showInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("Show dataset info")
                .popover(isPresented: $showInfo) {
                    DataInfoView(fileUrl: url, items: data.items)
                }

                Spacer()

                Text("\(data.total) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 16)

                Text("Page \(data.page)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await loadDataset(with: data.page - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(data.page == 1)

                Button {
                    Task {
                        await loadDataset(with: data.page + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!data.hasMore)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .onChange(of: url) { _, _ in
            Task {
                await loadDataset(with: 1)
            }
        }
        .task {
            await loadDataset(with: 1)
        }
        .onChange(of: sortOrder) { _, _ in
            Task {
                await loadDataset(with: 1)
            }
        }
    }
}

extension DataTableView {
    private func getSortParams() -> (column: String, direction: String) {
        guard let first = sortOrder.first else {
            return ("time", "DESC")
        }
        let direction = first.order == .forward ? "ASC" : "DESC"
        let column: String
        switch first.keyPath {
        case \PriceData.date: column = "time"
        case \PriceData.open: column = "open"
        case \PriceData.high: column = "high"
        case \PriceData.low: column = "low"
        case \PriceData.close: column = "close"
        case \PriceData.volume: column = "volume"
        default: column = "time"
        }
        return (column, direction)
    }

    func loadDataset(with page: Int) async {
        isLoading = true
        defer {
            isLoading = false
        }

        let sortParams = getSortParams()
        do {
            try dbService.initDatabase()
            try await dbService.loadDataset(filePath: url)
            data = try await dbService.fetchPriceData(
                page: page,
                pageSize: 500,
                sortColumn: sortParams.column,
                sortDirection: sortParams.direction
            )
        } catch {
            print("Error: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}

#Preview {
    DataTableView(url: URL(fileURLWithPath: "/tmp/test.parquet"))
        .environment(DuckDBService())
        .environment(AlertManager())
}
