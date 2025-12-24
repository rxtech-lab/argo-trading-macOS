import SwiftUI

struct DatasetPickerPopover: View {
    @Binding var selectedDataset: URL?
    @Binding var isPresented: Bool
    let datasetFiles: [URL]

    @State private var datasetFilter = ""

    private var filteredDatasets: [URL] {
        if datasetFilter.isEmpty {
            return datasetFiles
        }
        return datasetFiles.filter {
            $0.deletingPathExtension().lastPathComponent
                .localizedCaseInsensitiveContains(datasetFilter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter", text: $datasetFilter)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.bottom, 8)

            Divider()
                .padding(.bottom, 8)

            if filteredDatasets.isEmpty {
                Text(datasetFiles.isEmpty ? "No datasets available" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredDatasets, id: \.self) { file in
                            DatasetPickerItemView(
                                file: file,
                                isSelected: selectedDataset == file,
                                onSelect: {
                                    selectedDataset = file
                                    isPresented = false
                                    datasetFilter = ""
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    DatasetPickerPopover(
        selectedDataset: .constant(nil),
        isPresented: .constant(true),
        datasetFiles: [
            URL(fileURLWithPath: "/data/BTCUSDT_1hour_2024-01-01_2024-12-31.parquet"),
            URL(fileURLWithPath: "/data/ETHUSDT_4hour_2024-01-01_2024-06-30.parquet"),
            URL(fileURLWithPath: "/data/SOLUSDT_1day_2023-06-01_2024-06-01.parquet")
        ]
    )
    .padding()
}
