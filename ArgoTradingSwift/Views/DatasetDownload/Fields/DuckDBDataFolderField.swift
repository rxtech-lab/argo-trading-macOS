//
//  DuckDBDataFolderField.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/20/25.
//

import SwiftUI

struct DuckDBDataFolderField: View {
    @AppStorage("duckdb-data-folder") private var duckDBDataFolder: String = ""
    @State private var showFilePicker: Bool = false

    var body: some View {
        VStack {
            HStack {
                Text("Data Folder")
                Spacer()
                Text(duckDBDataFolder.isEmpty ? "Not selected" : duckDBDataFolder)
                    .foregroundColor(.gray)
                    .font(.footnote)
            }
            HStack {
                Spacer()
                Button("Select") {
                    showFilePicker = true
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let success) = result {
                self.duckDBDataFolder = success.first?.path ?? ""
            }
        }
    }
}
