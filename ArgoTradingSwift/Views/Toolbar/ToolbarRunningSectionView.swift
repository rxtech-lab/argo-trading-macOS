import SwiftUI

struct ToolbarRunningSectionView: View {
    @Binding var document: ArgoTradingDocument
    let status: ToolbarRunningStatus
    let datasetFiles: [URL]
    let strategyFiles: [URL]
    let selectedMode: EditorMode

    @State private var showDatasetPicker = false
    @State private var showSchemaPicker = false
    @State private var showTradingProviderPicker = false
    @State private var isHoveringDatasetButton = false
    @State private var isHoveringSchemaButton = false
    @State private var isHoveringTradingProviderButton = false

    private var isSchemaStrategyMissing: Bool {
        document.isSchemaStrategyMissing(strategyFiles: strategyFiles)
    }

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
                .foregroundStyle(isSchemaStrategyMissing ? .red : .primary)
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

            switch selectedMode {
            case .Backtest:
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
                        datasetFiles: datasetFiles
                    )
                }
            case .Trading:
                Button {
                    showTradingProviderPicker.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                        Text(document.selectedTradingProvider?.name ?? "Select provider")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHoveringTradingProviderButton ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
                }
                .frame(maxWidth: 150, alignment: .leading)
                .buttonStyle(.plain)
                .controlSize(.small)
                .onHover { hovering in
                    isHoveringTradingProviderButton = hovering
                }
                .popover(isPresented: $showTradingProviderPicker, arrowEdge: .bottom) {
                    TradingProviderPickerPopover(
                        document: $document,
                        isPresented: $showTradingProviderPicker
                    )
                }
            }

            Spacer()
            statusView()
                .frame(maxWidth: 400, alignment: .trailing)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
        .frame(minWidth: 700)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: status.animationId)
    }

    @ViewBuilder
    func statusView() -> some View {
        switch status {
        case .idle:
            Text("Idle")
                .font(.callout)
                .id("idle")

        case .running(let label):
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .id("running-\(label)")

        case .downloading(let label, let progress):
            HStack(spacing: 8) {
                Text("Downloading \(label)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .controlSize(.small)
                    .progressViewStyle(.circular)
                    .help("Downloaded \(progress.current) out of \(progress.total) files")
            }
            .id("downloading-\(label)")

        case .backtesting(let label, let progress):
            HStack(spacing: 8) {
                Text("\(label) \(progress.current)/\(progress.total)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Divider()

                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .controlSize(.small)
                    .progressViewStyle(.circular)
            }
            .id("backtesting-\(label)")

        case .error(let label, _, let date):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(label) **Failed**")
                    .font(.callout)
                Text("|")
                    .foregroundStyle(.tertiary)
                Text(formatDate(date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .id("error-\(label)")

        case .downloadCancelled(let label):
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(label) **Cancelled**")
                    .font(.callout)
            }
            .id("downloadCancelled-\(label)")

        case .trading(let label):
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .id("trading-\(label)")

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
            .id("finished-\(message)")
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
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        status: .idle,
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}

#Preview("Running") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        status: .running(label: "Building..."),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}

#Preview("Backtesting") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        status: .backtesting(label: "Backtesting", progress: Progress(current: 45, total: 100)),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}

#Preview("Error") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        status: .error(label: "", errors: ["Something went wrong"], at: Date()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}

#Preview("Finished") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        status: .finished(message: "Build Succeeded", at: Date()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}

#Preview("Missing Strategy") {
    let schema = Schema(name: "Test Schema", strategyPath: "")
    return ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument(
            schemas: [schema],
            selectedSchemaId: schema.id
        )),
        status: .idle,
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .padding()
}
