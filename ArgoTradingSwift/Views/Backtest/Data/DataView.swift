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

    var body: some View {
        VStack {
            Table(data.items) {
                TableColumn("Date") { price in
                    Text(price.date, format: .dateTime.year().month().day().hour().minute().second())
                }
                .width(200)
                TableColumn("Ticker") { price in
                    Text(price.ticker)
                }
                TableColumn("Open") { price in
                    Text("\(price.open, format: .number.precision(.fractionLength(2)))")
                }
                TableColumn("High") { price in
                    Text("\(price.high, format: .number.precision(.fractionLength(2)))")
                }
                TableColumn("Low") { price in
                    Text("\(price.low, format: .number.precision(.fractionLength(2)))")
                }
                TableColumn("Close") { price in
                    Text("\(price.close, format: .number.precision(.fractionLength(2)))")
                }
                TableColumn("Volume") { price in
                    Text("\(price.volume, format: .number.precision(.fractionLength(0)))")
                }
            }
        }
        .toolbar {
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
    }
}

extension DataView {
    func loadDataset(with page: Int) async {
        do {
            try dbService.initDatabase()
            try await dbService.loadDataset(filePath: url)
            data = try await dbService.fetchPriceData(page: page, pageSize: 500)
        } catch {
            print("Error: \(error)")
            alertManager.showAlert(message: error.localizedDescription)
        }
    }
}
