//
//  OrdersTableView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/27/25.
//

import SwiftUI

struct OrdersTableView: View {
    let filePath: URL
    let dataFilePath: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(BacktestResultService.self) private var backtestResultService

    @State private var data: PaginationResult<Order> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<Order>] = [KeyPathComparator(\.timestamp, order: .reverse)]
    @State private var isLoading: Bool = false
    @State private var selectedOrderForDetail: Order?

    var body: some View {
        VStack(spacing: 0) {
            tableView
            Divider()
            footerView
        }
        .onChange(of: filePath) { _, _ in
            Task { await loadOrders(page: 1) }
        }
        .task {
            await loadOrders(page: 1)
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadOrders(page: 1) }
        }
        .onChange(of: selectedRows) { _, newSelection in
            guard let firstId = newSelection.first,
                  let order = data.items.first(where: { $0.id == firstId }) else { return }
            backtestResultService.scrollChartToTimestamp(order.timestamp, dataFilePath: dataFilePath.path)
        }
    }

    private var tableView: some View {
        Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
            basicColumns
            metadataColumns
        }
        .contextMenu(forSelectionType: String.self) { selectedIds in
            if let firstId = selectedIds.first,
               let order = data.items.first(where: { $0.id == firstId }) {
                Button {
                    selectedOrderForDetail = order
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
        .sheet(item: $selectedOrderForDetail) { order in
            SurroundingPriceDataSheet(
                timestamp: order.timestamp,
                dataFilePath: dataFilePath,
                title: "\(order.symbol) - \(order.orderType.capitalized)"
            )
        }
    }

    @TableColumnBuilder<Order, KeyPathComparator<Order>>
    private var basicColumns: some TableColumnContent<Order, KeyPathComparator<Order>> {
        TableColumn("Timestamp", value: \.timestamp) { order in
            Text(order.timestamp, format: .dateTime.year().month().day().hour().minute().second())
        }
        .width(min: 140, ideal: 160)

        TableColumn("Symbol", value: \.symbol) { order in
            Text(order.symbol)
        }
        .width(min: 60, ideal: 80)

        TableColumn("Type", value: \.orderType) { order in
            Text(order.orderType)
        }
        .width(min: 50, ideal: 60)

        TableColumn("Position", value: \.positionType) { order in
            Text(order.positionType)
                .foregroundStyle(order.positionType == "long" ? .green : .red)
        }
        .width(min: 60, ideal: 70)

        TableColumn("Qty", value: \.quantity) { order in
            Text("\(order.quantity, format: .number.precision(.fractionLength(4)))")
        }
        .width(min: 60, ideal: 80)

        TableColumn("Price", value: \.price) { order in
            Text("\(order.price, format: .number.precision(.fractionLength(2)))")
        }
        .width(min: 60, ideal: 80)
    }

    @TableColumnBuilder<Order, KeyPathComparator<Order>>
    private var metadataColumns: some TableColumnContent<Order, KeyPathComparator<Order>> {
        TableColumn("Strategy", value: \.strategyName) { order in
            Text(order.strategyName)
        }
        .width(min: 80, ideal: 100)

        TableColumn("Reason", value: \.reason) { order in
            Text(order.reason)
        }
        .width(min: 80, ideal: 120)

        TableColumn("Message", value: \.message) { order in
            Text(order.message)
                .lineLimit(1)
        }
        .width(min: 100, ideal: 150)

        TableColumn("Completed") { order in
            Image(systemName: order.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(order.isCompleted ? .green : .secondary)
        }
        .width(min: 60, ideal: 70)
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Text("\(data.total) orders")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Text("Page \(data.page)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await loadOrders(page: data.page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(data.page == 1)

            Button {
                Task { await loadOrders(page: data.page + 1) }
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

extension OrdersTableView {
    private func getSortParams() -> (column: String, direction: String) {
        guard let first = sortOrder.first else {
            return ("timestamp", "DESC")
        }
        let direction = first.order == .forward ? "ASC" : "DESC"
        let column: String
        switch first.keyPath {
        case \Order.timestamp: column = "timestamp"
        case \Order.symbol: column = "symbol"
        case \Order.orderType: column = "order_type"
        case \Order.positionType: column = "position_type"
        case \Order.quantity: column = "quantity"
        case \Order.price: column = "price"
        case \Order.strategyName: column = "strategy_name"
        case \Order.reason: column = "reason"
        case \Order.message: column = "message"
        default: column = "timestamp"
        }
        return (column, direction)
    }

    func loadOrders(page: Int) async {
        isLoading = true
        defer { isLoading = false }

        let sortParams = getSortParams()
        do {
            try dbService.initDatabase()
            data = try await dbService.fetchOrderData(
                filePath: filePath,
                page: page,
                pageSize: 100,
                sortColumn: sortParams.column,
                sortDirection: sortParams.direction
            )
        } catch {
            print("Error loading orders: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}

#Preview {
    OrdersTableView(
        filePath: URL(fileURLWithPath: "/tmp/orders.parquet"),
        dataFilePath: URL(fileURLWithPath: "/tmp/data.parquet")
    )
    .environment(DuckDBService())
    .environment(AlertManager())
    .environment(BacktestResultService())
}
