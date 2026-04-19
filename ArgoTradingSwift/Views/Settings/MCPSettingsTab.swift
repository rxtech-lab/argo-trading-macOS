//
//  MCPSettingsTab.swift
//  ArgoTradingSwift
//
//  Preference pane for controlling the embedded MCP HTTP server: start/stop,
//  change port, and toggle autostart on launch.
//

import SwiftUI

struct MCPSettingsTab: View {
    @Environment(MCPServerService.self) private var mcp

    @State private var portString: String = ""

    var body: some View {
        @Bindable var mcp = mcp
        Form {
            Section {
                statusRow
                    .accessibilityIdentifier("argo.settings.mcp.statusLabel")
                if isRunning {
                    LabeledContent("Active sessions") {
                        Text(String(mcp.activeSessions))
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("argo.settings.mcp.activeSessions")
                    LabeledContent("Requests served") {
                        Text(String(mcp.totalRequests))
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("argo.settings.mcp.totalRequests")
                }
            } header: {
                Text("Status")
            }

            Section {
                HStack {
                    TextField("Port", text: $portString)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("argo.settings.mcp.portField")
                        .onSubmit(savePort)
                    Button("Apply", action: savePort)
                        .disabled(parsedPort == nil || parsedPort == mcp.desiredPort)
                }

                Toggle("Start on launch", isOn: $mcp.autostart)

                Picker("Bind address", selection: $mcp.bindAllInterfaces) {
                    Text("Localhost only (127.0.0.1)").tag(false)
                    Text("All interfaces (0.0.0.0)").tag(true)
                }
                .pickerStyle(.radioGroup)
                .accessibilityIdentifier("argo.settings.mcp.bindAddressPicker")
                .onChange(of: mcp.bindAllInterfaces) { _, _ in
                    if isRunning { Task { await mcp.restart() } }
                }

                HStack {
                    Button(action: toggleServer) {
                        Text(isRunning ? "Stop server" : "Start server")
                    }
                    .accessibilityIdentifier("argo.settings.mcp.startStopButton")

                    Button("Restart", action: restart)
                        .disabled(!isRunning)
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Default port is \(String(MCPServerService.defaultPort)). If the port is in use, the server probes upward until it finds a free one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { portString = String(mcp.desiredPort) }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch mcp.status {
        case .stopped:
            Label("Stopped", systemImage: "circle.fill")
                .foregroundStyle(.secondary)
        case .starting:
            Label("Starting…", systemImage: "circle.dotted")
                .foregroundStyle(.orange)
        case .running(let port):
            Label("Running on \(mcp.bindAllInterfaces ? "0.0.0.0" : "127.0.0.1"):\(String(port))", systemImage: "circle.fill")
                .foregroundStyle(.green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    private var isRunning: Bool {
        if case .running = mcp.status { return true }
        return false
    }

    private var parsedPort: Int? {
        guard let p = Int(portString), (1 ... 65535).contains(p) else { return nil }
        return p
    }

    private func toggleServer() {
        Task {
            if isRunning { await mcp.stop() }
            else { await mcp.start() }
        }
    }

    private func restart() {
        Task { await mcp.restart() }
    }

    private func savePort() {
        guard let p = parsedPort, p != mcp.desiredPort else { return }
        mcp.desiredPort = p
        portString = String(p)
        if isRunning {
            Task { await mcp.restart() }
        }
    }
}
