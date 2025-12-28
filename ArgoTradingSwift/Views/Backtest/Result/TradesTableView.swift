//
//  TradesTableView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct TradesTableView: View {
    let filePath: URL
    let dataFilePath: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager

    @State private var data: PaginationResult<Trade> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<Trade>] = [KeyPathComparator(\.timestamp, order: .reverse)]
    @State private var isLoading: Bool = false
    @State private var selectedTradeForDetail: Trade?

    var body: some View {
        VStack(spacing: 0) {
            tableView
            Divider()
            footerView
        }
        .onChange(of: filePath) { _, _ in
            Task { await loadTrades(page: 1) }
        }
        .task {
            await loadTrades(page: 1)
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadTrades(page: 1) }
        }
    }

    private var tableView: some View {
        Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
            basicColumns
            executionColumns
            metadataColumns
        }
        .contextMenu(forSelectionType: String.self) { selectedIds in
            if let firstId = selectedIds.first,
               let trade = data.items.first(where: { $0.id == firstId }) {
                Button {
                    selectedTradeForDetail = trade
                } label: {
                    Label("View Surrounding Price Data", systemImage: "chart.bar.xaxis")
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .padding()
                    .glassEffect()
            }
        }
        .sheet(item: $selectedTradeForDetail) { trade in
            SurroundingPriceDataSheet(
                timestamp: trade.timestamp,
                dataFilePath: dataFilePath,
                title: "\(trade.symbol) - \(trade.side.rawValue.capitalized)"
            )
        }
    }

    @TableColumnBuilder<Trade, KeyPathComparator<Trade>>
    private var basicColumns: some TableColumnContent<Trade, KeyPathComparator<Trade>> {
        TableColumn("Timestamp", value: \.timestamp) { trade in
            Text(trade.timestamp, format: .dateTime.year().month().day().hour().minute().second())
        }
        .width(min: 140, ideal: 160)

        TableColumn("Symbol", value: \.symbol) { trade in
            Text(trade.symbol)
        }
        .width(min: 60, ideal: 80)

        TableColumn("Side", value: \.side.rawValue) { trade in
            Text(trade.side.rawValue)
        }
        .width(min: 50, ideal: 60)

        TableColumn("Position", value: \.positionType) { trade in
            Text(trade.positionType)
                .foregroundStyle(trade.positionType == "long" ? .green : .red)
        }
        .width(min: 60, ideal: 70)

        TableColumn("Qty", value: \.quantity) { trade in
            Text("\(trade.quantity, format: .number.precision(.fractionLength(4)))")
        }
        .width(min: 60, ideal: 80)
    }

    @TableColumnBuilder<Trade, KeyPathComparator<Trade>>
    private var executionColumns: some TableColumnContent<Trade, KeyPathComparator<Trade>> {
        TableColumn("Price", value: \.price) { trade in
            Text("\(trade.price, format: .number.precision(.fractionLength(2)))")
        }
        .width(min: 60, ideal: 80)

        TableColumn("Exec Price", value: \.executedPrice) { trade in
            Text("\(trade.executedPrice, format: .number.precision(.fractionLength(2)))")
        }
        .width(min: 60, ideal: 80)

        TableColumn("Exec Qty", value: \.executedQty) { trade in
            Text("\(trade.executedQty, format: .number.precision(.fractionLength(4)))")
        }
        .width(min: 60, ideal: 80)

        TableColumn("PnL", value: \.pnl) { trade in
            Text("\(trade.pnl, format: .number.precision(.fractionLength(2)))")
                .foregroundStyle(trade.pnl >= 0 ? .green : .red)
        }
        .width(min: 60, ideal: 80)

        TableColumn("Commission", value: \.commission) { trade in
            Text("\(trade.commission, format: .number.precision(.fractionLength(4)))")
        }
        .width(min: 60, ideal: 80)
    }

    @TableColumnBuilder<Trade, KeyPathComparator<Trade>>
    private var metadataColumns: some TableColumnContent<Trade, KeyPathComparator<Trade>> {
        TableColumn("Strategy", value: \.strategyName) { trade in
            Text(trade.strategyName)
        }
        .width(min: 80, ideal: 100)

        TableColumn("Reason", value: \.reason) { trade in
            Text(trade.reason)
        }
        .width(min: 80, ideal: 120)

        TableColumn("Message", value: \.message) { trade in
            Text(trade.message)
                .lineLimit(1)
        }
        .width(min: 100, ideal: 150)

        TableColumn("Completed") { trade in
            Image(systemName: trade.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(trade.isCompleted ? .green : .secondary)
        }
        .width(min: 60, ideal: 70)
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Text("\(data.total) trades")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Text("Page \(data.page)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await loadTrades(page: data.page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(data.page == 1)

            Button {
                Task { await loadTrades(page: data.page + 1) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(!data.hasMore)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

extension TradesTableView {
    private func getSortParams() -> (column: String, direction: String) {
        guard let first = sortOrder.first else {
            return ("timestamp", "DESC")
        }
        let direction = first.order == .forward ? "ASC" : "DESC"
        let column: String
        switch first.keyPath {
        case \Trade.timestamp: column = "timestamp"
        case \Trade.symbol: column = "symbol"
        case \Trade.side: column = "order_type"
        case \Trade.positionType: column = "position_type"
        case \Trade.quantity: column = "quantity"
        case \Trade.price: column = "price"
        case \Trade.executedPrice: column = "executed_price"
        case \Trade.executedQty: column = "executed_qty"
        case \Trade.pnl: column = "pnl"
        case \Trade.commission: column = "commission"
        case \Trade.strategyName: column = "strategy_name"
        case \Trade.reason: column = "reason"
        case \Trade.message: column = "message"
        default: column = "timestamp"
        }
        return (column, direction)
    }

    func loadTrades(page: Int) async {
        isLoading = true
        defer { isLoading = false }

        let sortParams = getSortParams()
        do {
            try dbService.initDatabase()
            data = try await dbService.fetchTradeData(
                filePath: filePath,
                page: page,
                pageSize: 100,
                sortColumn: sortParams.column,
                sortDirection: sortParams.direction
            )
        } catch {
            print("Error loading trades: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}

#Preview {
    TradesTableView(
        filePath: URL(fileURLWithPath: "/tmp/trades.parquet"),
        dataFilePath: URL(fileURLWithPath: "/tmp/data.parquet")
    )
    .environment(DuckDBService())
    .environment(AlertManager())
}
