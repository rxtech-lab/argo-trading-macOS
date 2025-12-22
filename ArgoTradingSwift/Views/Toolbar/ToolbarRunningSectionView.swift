import SwiftUI

struct ToolbarRunningSectionView: View {
    let status: ToolbarRunningStatus
    @Environment(DatasetService.self) var datasetService

    @State private var selectedDataset: URL?
    @State private var showDatasetPicker = false
    @State private var datasetFilter = ""

    private var filteredDatasets: [URL] {
        if datasetFilter.isEmpty {
            return datasetService.datasetFiles
        }
        return datasetService.datasetFiles.filter {
            $0.deletingPathExtension().lastPathComponent
                .localizedCaseInsensitiveContains(datasetFilter)
        }
    }

    var body: some View {
        HStack {
            Menu {} label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text("No schema selected")
                        .lineLimit(1)
                }
            }
            .controlSize(.small)

            Image(systemName: "chevron.compact.forward")

            Button {
                showDatasetPicker.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "cylinder")
                    Text(selectedDataset?.deletingPathExtension().lastPathComponent ?? "Select dataset")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: 150, alignment: .leading)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .popover(isPresented: $showDatasetPicker, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Filter", text: $datasetFilter)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)

                    Divider()

                    if filteredDatasets.isEmpty {
                        Text(datasetService.datasetFiles.isEmpty ? "No datasets available" : "No matches")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredDatasets, id: \.self) { file in
                                    Button {
                                        selectedDataset = file
                                        showDatasetPicker = false
                                        datasetFilter = ""
                                    } label: {
                                        HStack {
                                            if selectedDataset == file {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.blue)
                                            } else {
                                                Image(systemName: "checkmark")
                                                    .opacity(0)
                                            }
                                            Image(systemName: "cylinder")
                                                .foregroundStyle(.secondary)
                                            Text(file.deletingPathExtension().lastPathComponent)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                    .background(selectedDataset == file ? Color.accentColor.opacity(0.1) : Color.clear)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .frame(width: 250)
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
        .frame(width: 500)
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
    ToolbarRunningSectionView(status: .idle)
        .environment(DatasetService())
        .padding()
}

#Preview("Running") {
    ToolbarRunningSectionView(status: .running(label: "Building..."))
        .environment(DatasetService())
        .padding()
}

#Preview("Backtesting") {
    ToolbarRunningSectionView(status: .backtesting(label: "Backtesting", progress: Progress(current: 45, total: 100)))
        .environment(DatasetService())
        .padding()
}

#Preview("Error") {
    ToolbarRunningSectionView(status: .error(errors: ["Something went wrong"], at: Date()))
        .environment(DatasetService())
        .padding()
}

#Preview("Finished") {
    ToolbarRunningSectionView(status: .finished(message: "Build Succeeded", at: Date()))
        .environment(DatasetService())
        .padding()
}
