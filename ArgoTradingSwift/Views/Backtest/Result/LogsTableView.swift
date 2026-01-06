//
//  LogsTableView.swift
//  ArgoTradingSwift
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

struct LogsTableView: View {
    let filePath: URL
    let dataFilePath: URL

    @Environment(DuckDBService.self) private var dbService
    @Environment(AlertManager.self) private var alertManager
    @Environment(BacktestResultService.self) private var backtestResultService

    @State private var data: PaginationResult<Log> = PaginationResult(items: [], total: 0, page: 0, pageSize: 0)
    @State private var selectedRows: Set<Int64> = []
    @State private var sortOrder: [KeyPathComparator<Log>] = [KeyPathComparator(\.timestamp, order: .reverse)]
    @State private var isLoading: Bool = false
    @State private var selectedLogForDetail: Log?
    @State private var levelFilter: LogLevel?

    var body: some View {
        VStack(spacing: 0) {
            tableView
            Divider()
            footerView
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                filterBar
            }
        }
        .onChange(of: filePath) { _, _ in
            Task { await loadLogs(page: 1) }
        }
        .task {
            await loadLogs(page: 1)
        }
        .onChange(of: sortOrder) { _, _ in
            Task { await loadLogs(page: 1) }
        }
        .onChange(of: levelFilter) { _, _ in
            Task { await loadLogs(page: 1) }
        }
        .onChange(of: selectedRows) { _, newSelection in
            guard let firstId = newSelection.first,
                  let log = data.items.first(where: { $0.id == firstId }) else { return }
            backtestResultService.scrollChartToTimestamp(log.timestamp, dataFilePath: dataFilePath.path)
        }
    }

    private var filterBar: some View {
        Picker("Level", selection: $levelFilter) {
            Text("All").tag(nil as LogLevel?)
            ForEach(LogLevel.allCases, id: \.self) { level in
                Text(level.rawValue)
                    .tag(level as LogLevel?)
            }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 300)
    }

    private var tableView: some View {
        Table(data.items, selection: $selectedRows, sortOrder: $sortOrder) {
            TableColumn("Timestamp", value: \.timestamp) { log in
                Text(log.timestamp, format: .dateTime.year().month().day().hour().minute().second())
            }
            .width(min: 140, ideal: 160)

            TableColumn("Symbol", value: \.symbol) { log in
                Text(log.symbol)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Level", value: \.level) { log in
                HStack(spacing: 4) {
                    Image(systemName: log.level.icon)
                        .foregroundStyle(log.level.foregroundColor)
                    Text(log.level.rawValue)
                        .foregroundStyle(log.level.foregroundColor)
                }
            }
            .width(min: 80, ideal: 100)

            TableColumn("Message", value: \.message) { log in
                Text(log.message)
                    .lineLimit(2)
            }
            .width(min: 200, ideal: 400)

            TableColumn("Fields", value: \.fields) { log in
                Text(log.fields)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 200)
        }
        .contextMenu(forSelectionType: Int64.self) { selectedIds in
            if let firstId = selectedIds.first,
               let log = data.items.first(where: { $0.id == firstId })
            {
                Button {
                    selectedLogForDetail = log
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
        .sheet(item: $selectedLogForDetail) { log in
            SurroundingPriceDataSheet(
                timestamp: log.timestamp,
                dataFilePath: dataFilePath,
                title: "\(log.symbol) - \(log.level.rawValue)"
            )
        }
    }

    private var footerView: some View {
        HStack {
            Spacer()

            Text("\(data.total) logs")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 16)

            Text("Page \(data.page)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await loadLogs(page: data.page - 1) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .disabled(data.page == 1)

            Button {
                Task { await loadLogs(page: data.page + 1) }
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

extension LogsTableView {
    private func getSortParams() -> (column: String, direction: String) {
        guard let first = sortOrder.first else {
            return ("timestamp", "DESC")
        }
        let direction = first.order == .forward ? "ASC" : "DESC"
        let column: String
        switch first.keyPath {
        case \Log.id: column = "id"
        case \Log.timestamp: column = "timestamp"
        case \Log.symbol: column = "symbol"
        case \Log.level: column = "level"
        case \Log.message: column = "message"
        case \Log.fields: column = "fields"
        default: column = "timestamp"
        }
        return (column, direction)
    }

    func loadLogs(page: Int) async {
        isLoading = true
        defer { isLoading = false }

        let sortParams = getSortParams()
        do {
            try dbService.initDatabase()
            data = try await dbService.fetchLogData(
                filePath: filePath,
                page: page,
                pageSize: 100,
                sortColumn: sortParams.column,
                sortDirection: sortParams.direction,
                levelFilter: levelFilter
            )
        } catch {
            print("Error loading logs: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}

#Preview {
    LogsTableView(
        filePath: URL(fileURLWithPath: "/tmp/logs.parquet"),
        dataFilePath: URL(fileURLWithPath: "/tmp/data.parquet")
    )
    .environment(DuckDBService())
    .environment(AlertManager())
    .environment(BacktestResultService())
}
