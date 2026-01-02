//
//  DataView.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI
import TabularData

struct DataView: View {
    let url: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @State private var data: PaginationResult<PriceData> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<Int> = []
    @State private var showChart: Bool = false
    @State private var showInfo = false
    @State private var sortOrder: [KeyPathComparator<PriceData>] = [KeyPathComparator(\.date, order: .reverse)]
    @State private var isLoading: Bool = false

    var body: some View {
        Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { price in
                Text(price.date, format: .dateTime.year().month().day().hour().minute().second())
            }
            .width(200)
            TableColumn("Ticker", value: \.ticker) { price in
                Text(price.ticker)
            }
            TableColumn("Open", value: \.open) { price in
                Text("\(price.open, format: .number.precision(.fractionLength(2)))")
            }
            TableColumn("High", value: \.high) { price in
                Text("\(price.high, format: .number.precision(.fractionLength(2)))")
            }
            TableColumn("Low", value: \.low) { price in
                Text("\(price.low, format: .number.precision(.fractionLength(2)))")
            }
            TableColumn("Close", value: \.close) { price in
                Text("\(price.close, format: .number.precision(.fractionLength(2)))")
            }
            TableColumn("Volume", value: \.volume) { price in
                Text("\(price.volume, format: .number.precision(.fractionLength(0)))")
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .padding()
                    .glassEffect()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    showInfo.toggle()
                } label: {
                    Label("Info", systemImage: "info.circle")
                }
                .help("Show dataset info")
                Button {
                    showChart = true
                } label: {
                    Label("Chart", systemImage: "chart.xyaxis.line")
                }
                .help("Show price chart")
            }
            ToolbarItemGroup(placement: .confirmationAction) {
                Button {
                    Task {
                        await loadDataset(with: data.page - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(data.page == 1)

                Button {
                    Task {
                        await loadDataset(with: data.page + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!data.hasMore)
            }
        }
        .popover(isPresented: $showInfo, content: {
            DataInfoView(fileUrl: url, items: data.items)
        })
        .onChange(of: url) { _, _ in
            Task {
                await loadDataset(with: 1)
            }
        }
        .task {
            Task {
                await loadDataset(with: 1)
            }
        }
        .onChange(of: sortOrder) { _, _ in
            Task {
                await loadDataset(with: 1)
            }
        }
    }
}

extension DataView {
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
