//
//  FilePickerField.swift
//  ArgoTradingSwift
//
//  Created by Qiwei Li on 4/21/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct FilePickerField: View {
    @Binding var selectedPath: String
    @State private var showFilePicker: Bool = false

    var title: String
    var description: String?
    var allowedContentTypes: [UTType]
    var allowsMultipleSelection: Bool
    var placeholderText: String

    init(
        title: String,
        description: String? = nil,
        selectedPath: Binding<String>,
        allowedContentTypes: [UTType] = [.folder],
        allowsMultipleSelection: Bool = false,
        placeholderText: String = "Not selected"
    ) {
        self.title = title
        self.description = description
        self._selectedPath = selectedPath
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.placeholderText = placeholderText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            if let description = description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(selectedPath.isEmpty ? placeholderText : selectedPath)
                    .foregroundColor(.gray)
                    .font(.footnote)
                Spacer()
                Button("Select") {
                    showFilePicker = true
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: allowsMultipleSelection
        ) { result in
            if case .success(let success) = result {
                self.selectedPath = success.first?.path ?? ""
            }
        }
    }
}
