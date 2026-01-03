//
//  MarksTableView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/31/25.
//

import SwiftUI

struct MarksTableView: View {
    let filePath: URL
    let dataFilePath: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(BacktestResultService.self) private var backtestResultService

    @State private var data: PaginationResult<Mark> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<String> = []
    @State private var sortOrder: [KeyPathComparator<Mark>] = [KeyPathComparator(\.title, order: .forward)]
    @State private var isLoading: Bool = false
    @State private var selectedMarkForDetail: Mark?

    var body: some View {
        VStack(spacing: 0) {
            tableView
            Divider()
            footerView
        }
        .onChange(of: filePath) { _, _ in
            Task { await loadMarks(page: 1) }
        }
        .task {
            await loadMarks(page: 1)
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadMarks(page: 1) }
        }
        .onChange(of: selectedRows) { _, newSelection in
            guard let firstId = newSelection.first,
                  let mark = data.items.first(where: { $0.id == firstId })
            else {
                return
            }

            let signal = mark.signal
            backtestResultService.scrollChartToTimestamp(signal.time, dataFilePath: dataFilePath.path)
        }
    }

    private var tableView: some View {
        Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
            basicColumns
            signalColumns
        }
        .contextMenu(forSelectionType: String.self) { selectedIds in
            if let firstId = selectedIds.first,
               let mark = data.items.first(where: { $0.id == firstId })
            {
                Button {
                    selectedMarkForDetail = mark
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
        .sheet(item: $selectedMarkForDetail) { mark in
            SurroundingPriceDataSheet(
                timestamp: mark.signal.time,
                dataFilePath: dataFilePath,
                title: "\(mark.title) - \(mark.category)"
            )
        }
    }

    @TableColumnBuilder<Mark, KeyPathComparator<Mark>>
    private var basicColumns: some TableColumnContent<Mark, KeyPathComparator<Mark>> {
        TableColumn("Signal Time") { mark in
            Text(mark.signal.time, format: .dateTime.year().month().day().hour().minute().second())
        }
        .width(min: 140, ideal: 160)

        TableColumn("Title", value: \.title) { mark in
            Text(mark.title)
        }
        .width(min: 100, ideal: 120)

        TableColumn("Category", value: \.category) { mark in
            Text(mark.category)
        }
        .width(min: 80, ideal: 100)

        TableColumn("Shape", value: \.shape.rawValue) { mark in
            HStack(spacing: 4) {
                shapeIcon(for: mark.shape, color: mark.color.toColor())
                Text(mark.shape.rawValue.capitalized)
            }
        }
        .width(min: 70, ideal: 90)

        TableColumn("Color", value: \.color) { mark in
            HStack(spacing: 4) {
                Text(mark.color.rawValue().capitalized)
                    .foregroundStyle(mark.color.toColor())
            }
        }
        .width(min: 80, ideal: 100)

        TableColumn("Message", value: \.message) { mark in
            Text(mark.message)
                .lineLimit(1)
        }
        .width(min: 120, ideal: 180)
    }

    @TableColumnBuilder<Mark, KeyPathComparator<Mark>>
    private var signalColumns: some TableColumnContent<Mark, KeyPathComparator<Mark>> {
        TableColumn("Signal Type") { mark in
            Text(mark.signal.type.rawValue)
                .foregroundStyle(mark.signal.type.isBuy ? .green : mark.signal.type.isSell ? .red : .secondary)
        }
        .width(min: 80, ideal: 100)

        TableColumn("Signal Name") { mark in
            Text(mark.signal.name)
                .foregroundStyle(.primary)
        }
        .width(min: 80, ideal: 100)

        TableColumn("Symbol") { mark in
            Text(mark.signal.symbol)
                .foregroundStyle(.primary)
        }
        .width(min: 60, ideal: 80)
    }

    @ViewBuilder
    private func shapeIcon(for shape: MarkShape, color: Color) -> some View {
        switch shape {
        case .circle:
            Circle()
                .foregroundColor(color)
                .frame(width: 10, height: 10)
        case .square:
            Rectangle()
                .foregroundColor(color)
                .frame(width: 10, height: 10)
        case .triangle:
            Image(systemName: "triangle.fill")
                .foregroundColor(color)
                .font(.system(size: 10))
        }
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Text("\(data.total) marks")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Text("Page \(data.page)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await loadMarks(page: data.page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(data.page == 1)

            Button {
                Task { await loadMarks(page: data.page + 1) }
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

extension MarksTableView {
    private func getSortParams() -> (column: String, direction: String) {
        guard let first = sortOrder.first else {
            return ("id", "ASC")
        }
        let direction = first.order == .forward ? "ASC" : "DESC"
        let column: String
        switch first.keyPath {
        case \Mark.title: column = "title"
        case \Mark.category: column = "category"
        case \Mark.shape: column = "shape"
        case \Mark.color: column = "color"
        case \Mark.message: column = "message"
        case \Mark.marketDataId: column = "market_data_id"
        default: column = "id"
        }
        return (column, direction)
    }

    func loadMarks(page: Int) async {
        isLoading = true
        defer { isLoading = false }

        let sortParams = getSortParams()
        do {
            try dbService.initDatabase()
            data = try await dbService.fetchMarkData(
                filePath: filePath,
                page: page,
                pageSize: 100,
                sortColumn: sortParams.column,
                sortDirection: sortParams.direction
            )
        } catch {
            print("Error loading marks: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}

#Preview {
    MarksTableView(
        filePath: URL(fileURLWithPath: "/tmp/marks.parquet"),
        dataFilePath: URL(fileURLWithPath: "/tmp/data.parquet")
    )
    .environment(DuckDBService())
    .environment(AlertManager())
    .environment(BacktestResultService())
}
