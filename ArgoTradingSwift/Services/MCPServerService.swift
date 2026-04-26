//
//  MCPServerService.swift
//  ArgoTradingSwift
//
//  Owns the MCP server lifecycle using the Streamable HTTP transport.
//  A single TCP listener accepts HTTP requests on localhost; each client
//  session gets its own Server + StatefulHTTPServerTransport pair, keyed
//  by the Mcp-Session-Id header. Exposes session counts and total
//  requests to the Settings UI.
//

import Foundation
import MCP
import Network
import SwiftUI

@Observable
@MainActor
final class MCPServerService {
    enum Status: Equatable {
        case stopped
        case starting
        case running(port: Int)
        case error(String)
    }

    // Exposed UI state
    private(set) var status: Status = .stopped
    /// Clients that have completed `initialize` and whose session has not been terminated.
    private(set) var activeSessions: Int = 0
    /// Cumulative HTTP requests served since the server last started.
    private(set) var totalRequests: Int = 0

    // Desired port. Start probing from here.
    var desiredPort: Int {
        didSet {
            UserDefaults.standard.set(desiredPort, forKey: Self.portDefaultsKey)
        }
    }

    var autostart: Bool {
        didSet {
            UserDefaults.standard.set(autostart, forKey: Self.autostartDefaultsKey)
        }
    }

    /// When true, bind to 0.0.0.0 (LAN-reachable). When false, bind only to
    /// the loopback interface so nothing outside this machine can connect.
    var bindAllInterfaces: Bool {
        didSet {
            UserDefaults.standard.set(bindAllInterfaces, forKey: Self.bindAllInterfacesDefaultsKey)
        }
    }

    static let portDefaultsKey = "mcp.port"
    static let autostartDefaultsKey = "mcp.autostart"
    static let bindAllInterfacesDefaultsKey = "mcp.bindAllInterfaces"
    static let defaultPort = 33321

    private var currentPort: Int?
    private var httpServer: MCPHTTPServer?

    init() {
        let defaults = UserDefaults.standard
        let storedPort = defaults.integer(forKey: Self.portDefaultsKey)
        self.desiredPort = storedPort > 0 ? storedPort : Self.defaultPort
        // autostart defaults to true when unset
        if defaults.object(forKey: Self.autostartDefaultsKey) == nil {
            self.autostart = true
        } else {
            self.autostart = defaults.bool(forKey: Self.autostartDefaultsKey)
        }
        // Default to loopback-only for safety.
        self.bindAllInterfaces = defaults.bool(forKey: Self.bindAllInterfacesDefaultsKey)
    }

    /// Determine the port to bind to. Launch args/env override `desiredPort` —
    /// used by UI tests to pin a deterministic port. Returns (port, pinned) where
    /// `pinned = true` means no probing (fail on conflict).
    func resolveStartupPort() -> (port: Int, pinned: Bool) {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ArgoMcpPort"),
           idx + 1 < args.count,
           let p = Int(args[idx + 1])
        {
            return (p, true)
        }
        if let envPort = ProcessInfo.processInfo.environment["ARGO_MCP_PORT"],
           let p = Int(envPort)
        {
            return (p, true)
        }
        return (desiredPort, false)
    }

    func startIfAutostartEnabled() {
        if autostart {
            Task { await start() }
        }
    }

    /// Awaitable variant for `.task` modifiers that want to run the autostart
    /// inline. Safe to call multiple times — `start()` is a no-op when already
    /// running.
    func startIfAutostartEnabledAwait() async {
        if autostart {
            await start()
        }
    }

    func start() async {
        guard case .stopped = status else { return }
        status = .starting

        let (startPort, pinned) = resolveStartupPort()
        let maxTries = pinned ? 1 : 100
        let bindAll = bindAllInterfaces

        for i in 0 ..< maxTries {
            let port = startPort + i
            do {
                try await bootstrap(on: port, bindAllInterfaces: bindAll)
                currentPort = port
                status = .running(port: port)
                return
            } catch MCPServerError.portInUse where !pinned {
                continue
            } catch {
                status = .error(error.localizedDescription)
                return
            }
        }
        status = .error(pinned
            ? "Port \(startPort) is in use"
            : "No free port in range \(startPort)–\(startPort + maxTries - 1)")
    }

    func stop() async {
        if let httpServer { await httpServer.stop() }
        httpServer = nil
        currentPort = nil
        status = .stopped
        activeSessions = 0
        totalRequests = 0
    }

    func restart() async {
        await stop()
        await start()
    }

    private func bootstrap(on port: Int, bindAllInterfaces: Bool) async throws {
        activeSessions = 0
        totalRequests = 0

        let server = MCPHTTPServer(
            bindAllInterfaces: bindAllInterfaces,
            onStatsChange: { [weak self] active, total in
                Task { @MainActor in
                    self?.activeSessions = active
                    self?.totalRequests = total
                }
            }
        )
        try await server.start(port: port, loopbackOnly: !bindAllInterfaces)
        self.httpServer = server
    }
}

enum MCPServerError: LocalizedError {
    case portInUse(Int)
    case listenerFailed(String)

    var errorDescription: String? {
        switch self {
        case .portInUse(let p): return "Port \(p) is already in use"
        case .listenerFailed(let m): return "Listener failed: \(m)"
        }
    }
}

// MARK: - Embedded HTTP server (Streamable HTTP) backed by Network.framework

/// HTTP server that implements the MCP Streamable HTTP transport. Each client
/// session owns a `Server` + `StatefulHTTPServerTransport` pair, keyed by the
/// `Mcp-Session-Id` header. POST/GET may return SSE streams, which are piped
/// back to the HTTP connection until the transport closes the stream.
actor MCPHTTPServer {
    private struct Session {
        let server: MCP.Server
        let transport: StatefulHTTPServerTransport
    }

    private let bindAllInterfaces: Bool
    private let onStatsChange: @Sendable (_ active: Int, _ total: Int) -> Void

    private var listener: NWListener?
    private var sessions: [String: Session] = [:]
    private var totalRequests = 0

    init(
        bindAllInterfaces: Bool,
        onStatsChange: @escaping @Sendable (_ active: Int, _ total: Int) -> Void = { _, _ in }
    ) {
        self.bindAllInterfaces = bindAllInterfaces
        self.onStatsChange = onStatsChange
    }

    func start(port: Int, loopbackOnly: Bool) async throws {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw MCPServerError.listenerFailed("Invalid port \(port)")
        }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        if loopbackOnly {
            params.requiredInterfaceType = .loopback
        }
        let listener = try NWListener(using: params, on: nwPort)
        self.listener = listener

        let readyWaiter = AsyncThrowingStream<Void, Error>.makeStream()
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                readyWaiter.continuation.yield(())
                readyWaiter.continuation.finish()
            case .failed(let err):
                let mapped: Error
                if case .posix(let code) = err, code == .EADDRINUSE {
                    mapped = MCPServerError.portInUse(port)
                } else {
                    mapped = MCPServerError.listenerFailed(err.localizedDescription)
                }
                readyWaiter.continuation.finish(throwing: mapped)
            case .cancelled:
                readyWaiter.continuation.finish()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            Task { await self.accept(connection) }
        }
        listener.start(queue: .global(qos: .userInitiated))

        for try await _ in readyWaiter.stream { break }
    }

    func stop() async {
        listener?.cancel()
        listener = nil
        for (_, session) in sessions {
            await session.server.stop()
        }
        sessions.removeAll()
        onStatsChange(0, totalRequests)
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        Task {
            await self.handle(connection)
        }
    }

    private func handle(_ connection: NWConnection) async {
        totalRequests += 1
        onStatsChange(sessions.count, totalRequests)
        do {
            let request = try await readHTTPRequest(from: connection)
            try await route(request, connection: connection)
        } catch {
            let body = Data(#"{"error":"\#(error.localizedDescription)"}"#.utf8)
            try? await writeRawResponse(
                status: 400,
                headers: ["Content-Type": "application/json", "Connection": "close"],
                body: body,
                to: connection
            )
            connection.cancel()
        }
    }

    private func route(_ request: MCP.HTTPRequest, connection: NWConnection) async throws {
        let sessionID = request.header(HTTPHeaderName.sessionID)
        let method = request.method.uppercased()

        // Existing session: forward directly to its transport.
        if let sid = sessionID, let session = sessions[sid] {
            let response = await session.transport.handleRequest(request)
            try await write(response: response, to: connection)
            if method == "DELETE" {
                await removeSession(sid)
            }
            return
        }

        // No session yet. Only a POST with an initialize body can open one.
        if method == "POST", let body = request.body, isInitializeRequest(body) {
            try await openSessionAndForward(initialRequest: request, connection: connection)
            return
        }

        // Anything else without a valid session is rejected.
        let body = Data(#"{"jsonrpc":"2.0","error":{"code":-32600,"message":"Missing or unknown MCP-Session-Id"},"id":null}"#.utf8)
        try await writeRawResponse(
            status: 400,
            headers: ["Content-Type": "application/json", "Connection": "close"],
            body: body,
            to: connection
        )
        connection.cancel()
    }

    private func openSessionAndForward(
        initialRequest: MCP.HTTPRequest,
        connection: NWConnection
    ) async throws {
        let validators: [any HTTPRequestValidator] = [
            bindAllInterfaces ? OriginValidator.disabled : OriginValidator.localhost(),
            AcceptHeaderValidator(mode: .sseRequired),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
            SessionValidator(),
        ]
        let transport = StatefulHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: validators)
        )
        let server = MCP.Server(
            name: "ArgoTradingSwift",
            version: Bundle.main.appVersion ?? "0.0.0",
            instructions: "Control ArgoTradingSwift: import strategies, read/update schemas, list data, select, and run backtests.",
            capabilities: .init(logging: .init(), tools: .init())
        )
        await registerHandlers(on: server)
        try await server.start(transport: transport)

        let response = await transport.handleRequest(initialRequest)
        if let sid = response.headers[HTTPHeaderName.sessionID] {
            sessions[sid] = Session(server: server, transport: transport)
            onStatsChange(sessions.count, totalRequests)
        } else {
            // Transport rejected the request (validation error, etc.) — tear down the stub.
            await server.stop()
        }
        try await write(response: response, to: connection)
    }

    private func removeSession(_ sid: String) async {
        if let session = sessions.removeValue(forKey: sid) {
            await session.server.stop()
            onStatsChange(sessions.count, totalRequests)
        }
    }

    private func registerHandlers(on server: MCP.Server) async {
        let tools = MCPToolCatalog.allTools

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: tools)
        }

        await server.withMethodHandler(CallTool.self) { [weak server] params in
            await MCPToolDispatcher.dispatch(
                name: params.name,
                arguments: params.arguments,
                server: server
            )
        }
    }

    private func isInitializeRequest(_ body: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return false
        }
        return (json["method"] as? String) == "initialize"
    }

    // MARK: - HTTP response writing

    private func write(response: MCP.HTTPResponse, to connection: NWConnection) async throws {
        switch response {
        case .stream(let stream, let headers):
            try await writeStreamingResponse(stream: stream, headers: headers, to: connection)
        case .accepted, .ok, .data, .error:
            try await writeBufferedResponse(response, to: connection)
            connection.cancel()
        }
    }

    private func writeBufferedResponse(_ response: MCP.HTTPResponse, to connection: NWConnection) async throws {
        var headers = response.headers
        let body = response.bodyData ?? Data()
        headers["Content-Length"] = "\(body.count)"
        headers["Connection"] = "close"
        try await writeRawResponse(
            status: response.statusCode,
            headers: headers,
            body: body,
            to: connection
        )
    }

    private func writeStreamingResponse(
        stream: AsyncThrowingStream<Data, Error>,
        headers: [String: String],
        to connection: NWConnection
    ) async throws {
        var outHeaders = headers
        outHeaders["Transfer-Encoding"] = "chunked"
        outHeaders["Connection"] = "keep-alive"
        try await writeHead(status: 200, headers: outHeaders, to: connection)
        do {
            for try await chunk in stream {
                try await send(connection: connection, data: encodeChunk(chunk))
            }
            try await send(connection: connection, data: encodeChunk(Data()))
        } catch {
            // Client disconnected mid-stream or the stream errored — just close.
        }
        connection.cancel()
    }

    private func encodeChunk(_ data: Data) -> Data {
        let sizeLine = String(format: "%X\r\n", data.count)
        var out = Data(sizeLine.utf8)
        out.append(data)
        out.append(Data("\r\n".utf8))
        return out
    }

    private func writeHead(status: Int, headers: [String: String], to connection: NWConnection) async throws {
        var head = "HTTP/1.1 \(status) \(httpReason(status))\r\n"
        for (k, v) in headers {
            head += "\(k): \(v)\r\n"
        }
        head += "\r\n"
        try await send(connection: connection, data: Data(head.utf8))
    }

    private func writeRawResponse(status: Int, headers: [String: String], body: Data, to connection: NWConnection) async throws {
        var head = "HTTP/1.1 \(status) \(httpReason(status))\r\n"
        for (k, v) in headers {
            head += "\(k): \(v)\r\n"
        }
        head += "\r\n"
        var data = Data(head.utf8)
        data.append(body)
        try await send(connection: connection, data: data)
    }

    private func httpReason(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 409: return "Conflict"
        case 415: return "Unsupported Media Type"
        case 500: return "Internal Server Error"
        default: return "Status"
        }
    }

    // MARK: - HTTP parse

    private func readHTTPRequest(from connection: NWConnection) async throws -> MCP.HTTPRequest {
        var buffer = Data()
        while buffer.range(of: Data("\r\n\r\n".utf8)) == nil {
            let chunk = try await receive(connection: connection, max: 64 * 1024)
            if chunk.isEmpty { break }
            buffer.append(chunk)
            if buffer.count > 1 * 1024 * 1024 {
                throw MCPServerError.listenerFailed("Header too large")
            }
        }
        guard let headerEndRange = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            throw MCPServerError.listenerFailed("Malformed HTTP request")
        }
        let headerData = buffer.subdata(in: buffer.startIndex ..< headerEndRange.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            throw MCPServerError.listenerFailed("Headers not UTF-8")
        }
        let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            throw MCPServerError.listenerFailed("Missing request line")
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            throw MCPServerError.listenerFailed("Malformed request line")
        }
        let method = String(parts[0])
        let path = String(parts[1])

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { continue }
            if let colon = line.firstIndex(of: ":") {
                let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }

        var body = buffer.subdata(in: headerEndRange.upperBound ..< buffer.endIndex)
        let contentLength = headers.first { $0.key.lowercased() == "content-length" }
            .flatMap { Int($0.value) } ?? 0
        while body.count < contentLength {
            let chunk = try await receive(connection: connection, max: 64 * 1024)
            if chunk.isEmpty { break }
            body.append(chunk)
        }
        if body.count > contentLength {
            body = body.subdata(in: 0 ..< contentLength)
        }

        return MCP.HTTPRequest(
            method: method,
            headers: headers,
            body: body.isEmpty ? nil : body,
            path: path
        )
    }

    // MARK: - NWConnection bridging

    private func receive(connection: NWConnection, max: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, isComplete, error in
                if let error { cont.resume(throwing: error); return }
                if let data, !data.isEmpty { cont.resume(returning: data); return }
                if isComplete { cont.resume(returning: Data()); return }
                cont.resume(returning: Data())
            }
        }
    }

    private func send(connection: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error); return }
                cont.resume()
            })
        }
    }
}
