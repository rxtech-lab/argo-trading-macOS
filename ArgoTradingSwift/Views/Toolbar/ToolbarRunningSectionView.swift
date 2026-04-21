import SwiftUI

struct ToolbarRunningSectionView: View {
    @Binding var document: ArgoTradingDocument
    let datasetFiles: [URL]
    let strategyFiles: [URL]
    let selectedMode: EditorMode

    var body: some View {
        HStack {
            ToolbarPickersView(
                document: $document,
                datasetFiles: datasetFiles,
                strategyFiles: strategyFiles,
                selectedMode: selectedMode
            )

            Spacer()
            ToolbarRunningStatusBadgeView()
                .frame(maxWidth: 400, alignment: .trailing)
        }
        .frame(minWidth: 700)
        .clipped()
    }
}

struct ToolbarRunningStatusBadgeView: View {
    @Environment(ToolbarStatusService.self) private var toolbarStatusService

    var body: some View {
        statusView(for: toolbarStatusService.toolbarRunningStatus)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.25), value: toolbarStatusService.toolbarRunningStatus.animationId)
    }

    @ViewBuilder
    func statusView(for status: ToolbarRunningStatus) -> some View {
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
                    .help("Running progress \(Int(progress.percentage))%")
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

private func previewService(_ status: ToolbarRunningStatus) -> ToolbarStatusService {
    let service = ToolbarStatusService()
    service.setStatusImmediately(status)
    return service
}

#Preview("Idle") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.idle))
    .padding()
}

#Preview("Running") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.running(label: "Building...")))
    .padding()
}

#Preview("Backtesting") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.backtesting(label: "Backtesting", progress: Progress(current: 45, total: 100))))
    .padding()
}

#Preview("Error") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.error(label: "", errors: ["Something went wrong"], at: Date())))
    .padding()
}

#Preview("Finished") {
    ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument()),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.finished(message: "Build Succeeded", at: Date())))
    .padding()
}

#Preview("Missing Strategy") {
    let schema = Schema(name: "Test Schema", strategyPath: "")
    return ToolbarRunningSectionView(
        document: .constant(ArgoTradingDocument(
            schemas: [schema],
            selectedSchemaId: schema.id
        )),
        datasetFiles: [],
        strategyFiles: [],
        selectedMode: .Backtest
    )
    .environment(previewService(.idle))
    .padding()
}
