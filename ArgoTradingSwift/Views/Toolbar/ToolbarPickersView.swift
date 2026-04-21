import SwiftUI

struct ToolbarPickersView: View {
    @Binding var document: ArgoTradingDocument
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
        selectedMode == .Backtest && document.isSchemaStrategyMissing(strategyFiles: strategyFiles)
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
        }
    }
}
