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
        FilePickerField(
            title: "Data Folder",
            selectedPath: $duckDBDataFolder
        )
    }
}
