//
//  ParquetFileRow.swift
//  ArgoTradingSwift
//
//  Created by Claude on 12/21/25.
//

import SwiftUI

struct ParquetFileRow: View {
    let fileName: String

    private var parsed: ParsedParquetFileName? {
        ParquetFileNameParser.parse(fileName)
    }

    var body: some View {
        if let parsed {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(parsed.ticker)
                        .fontWeight(.medium)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(parsed.timespan)
                        .foregroundStyle(.secondary)
                }
                .font(.body)
                Text(parsed.dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(fileName.replacingOccurrences(of: ".parquet", with: ""))
                .truncationMode(.middle)
        }
    }
}
