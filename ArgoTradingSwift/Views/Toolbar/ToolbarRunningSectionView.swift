import SwiftUI

struct ToolbarRunningSectionView: View {
    @Binding var document: ArgoTradingDocument
    let status: ToolbarRunningStatus
    @Environment(DatasetService.self) var datasetService
    @Environment(SchemaService.self) var schemaService

    @State private var showDatasetPicker = false
    @State private var showSchemaPicker = false
    @State private var isHoveringDatasetButton = false
    @State private var isHoveringSchemaButton = false

    var body: some View {
        HStack {
            Button {
                showSchemaPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text(document.selectedSchema?.name ?? "Select schema")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(maxWidth: 150, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHoveringSchemaButton ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(12)
            }
            .fixedSize(horizontal: true, vertical: false)
            .buttonStyle(.plain)
            .controlSize(.small)
            .onHover { hovering in
                isHoveringSchemaButton = hovering
            }
            .popover(isPresented: $showSchemaPicker, arrowEdge: .bottom) {
                SchemaPickerPopover(
                    document: $document,
                    isPresented: $showSchemaPicker
                )
            }

            Image(systemName: "chevron.compact.forward")

            Button {
                showDatasetPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cylinder")
                    Text(document.selectedDatasetURL?.deletingPathExtension().lastPathComponent ?? "Select dataset")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHoveringDatasetButton ? Color.accentColor.opacity(0.1) : Color.clear)
                .cornerRadius(12)
            }
            .frame(maxWidth: 150, alignment: .leading)
            .buttonStyle(.plain)
            .controlSize(.small)
            .onHover { hovering in
                isHoveringDatasetButton = hovering
            }
            .popover(isPresented: $showDatasetPicker, arrowEdge: .bottom) {
                DatasetPickerPopover(
                    document: $document,
                    isPresented: $showDatasetPicker,
                    datasetFiles: datasetService.datasetFiles
                )
            }

            Spacer()
            statusView()
                .id(status.animationId)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: status.animationId)
        }
        .frame(minWidth: 500)
        .clipped()
    }

    @ViewBuilder
    func statusView() -> some View {
        switch status {
        case .idle:
            Text("Idle")
                .font(.callout)

        case .running(let label):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .backtesting(let label, let progress):
            HStack(spacing: 8) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("\(progress.current)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("\(progress.total)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .frame(width: 100)
            }

        case .error(_, let date):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Build **Failed**")
                    .font(.callout)
                Text("|")
                    .foregroundStyle(.tertiary)
                Text(formatDate(date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .finished(let message, let date):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
                    .font(.callout)
                Text("|")
                    .foregroundStyle(.tertiary)
                Text(formatDate(date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeString)"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            return "\(dateFormatter.string(from: date)) at \(timeString)"
        }
    }
}

#Preview("Idle") {
    ToolbarRunningSectionView(document: .constant(ArgoTradingDocument()), status: .idle)
        .environment(DatasetService())
        .environment(SchemaService())
        .padding()
}

#Preview("Running") {
    ToolbarRunningSectionView(document: .constant(ArgoTradingDocument()), status: .running(label: "Building..."))
        .environment(DatasetService())
        .environment(SchemaService())
        .padding()
}

#Preview("Backtesting") {
    ToolbarRunningSectionView(document: .constant(ArgoTradingDocument()), status: .backtesting(label: "Backtesting", progress: Progress(current: 45, total: 100)))
        .environment(DatasetService())
        .environment(SchemaService())
        .padding()
}

#Preview("Error") {
    ToolbarRunningSectionView(document: .constant(ArgoTradingDocument()), status: .error(errors: ["Something went wrong"], at: Date()))
        .environment(DatasetService())
        .environment(SchemaService())
        .padding()
}

#Preview("Finished") {
    ToolbarRunningSectionView(document: .constant(ArgoTradingDocument()), status: .finished(message: "Build Succeeded", at: Date()))
        .environment(DatasetService())
        .environment(SchemaService())
        .padding()
}
