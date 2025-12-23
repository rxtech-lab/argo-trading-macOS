import SwiftUI

struct DatasetPickerItemView: View {
    let file: URL
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    private var fileName: String {
        file.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "checkmark")
                        .opacity(0)
                }
                Image(systemName: "cylinder")
                    .foregroundStyle(.secondary)
                ParquetFileRow(fileName: fileName)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.1)
                    : (isHovered ? Color.primary.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DatasetPickerItemView(
            file: URL(fileURLWithPath: "/data/BTCUSDT_1hour_2024-01-01_2024-12-31.parquet"),
            isSelected: true,
            onSelect: {}
        )
        DatasetPickerItemView(
            file: URL(fileURLWithPath: "/data/ETHUSDT_4hour_2024-01-01_2024-06-30.parquet"),
            isSelected: false,
            onSelect: {}
        )
    }
    .frame(width: 280)
    .padding()
}
