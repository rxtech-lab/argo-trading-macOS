//
//  MCPTestClient.swift
//  ArgoTradingSwiftUITests
//
//  Thin JSON-RPC helper that talks to the embedded MCP server using the
//  Streamable HTTP transport. Keeps track of the session ID handed out
//  by the initialize response and parses the SSE-wrapped JSON-RPC result
//  returned for each request.
//

import Foundation

final class MCPTestClient: @unchecked Sendable {
    let port: Int
    var protocolVersion: String = "2025-06-18"
    private var sessionID: String?

    init(port: Int) {
        self.port = port
    }

    struct RPCError: Error, CustomStringConvertible {
        let code: Int
        let message: String
        let httpStatus: Int?
        var description: String { "MCP error (code=\(code), http=\(httpStatus.map(String.init) ?? "?")): \(message)" }
    }

    enum ClientError: Error, CustomStringConvertible {
        case invalidResponse(String)
        case decoding(String)
        var description: String {
            switch self {
            case .invalidResponse(let m): return "Invalid response: \(m)"
            case .decoding(let m): return "Decoding failed: \(m)"
            }
        }
    }

    /// Poll the server until it responds to an `initialize` request, or the timeout fires.
    func waitUntilReady(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                try await initializeSession()
                return
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
        throw lastError ?? ClientError.invalidResponse("Server did not become ready in \(Int(timeout))s")
    }

    @discardableResult
    func listTools() async throws -> [String] {
        let result = try await rpc(method: "tools/list", params: [:])
        guard let tools = result["tools"] as? [[String: Any]] else {
            throw ClientError.decoding("tools/list missing tools array")
        }
        return tools.compactMap { $0["name"] as? String }
    }

    /// Returns the parsed `CallTool.Result` JSON payload (top-level fields: `content`, `structuredContent`, `isError`).
    func callTool(_ name: String, arguments: [String: Any] = [:]) async throws -> [String: Any] {
        try await rpc(method: "tools/call", params: [
            "name": name,
            "arguments": arguments,
        ])
    }

    /// Low-level JSON-RPC call. Returns the decoded `result` object.
    func rpc(method: String, params: [String: Any]) async throws -> [String: Any] {
        if sessionID == nil {
            try await initializeSession()
        }
        return try await sendRPC(method: method, params: params, includeProtocolVersion: true)
    }

    // MARK: - Session initialization

    private func initializeSession() async throws {
        sessionID = nil
        let result = try await sendRPC(
            method: "initialize",
            params: [
                "protocolVersion": protocolVersion,
                "capabilities": [:],
                "clientInfo": ["name": "argo-ui-test", "version": "1.0"],
            ],
            includeProtocolVersion: false
        )
        // Just verifying the handshake succeeded — session ID was captured from headers.
        _ = result
    }

    private func sendRPC(
        method: String,
        params: [String: Any],
        includeProtocolVersion: Bool
    ) async throws -> [String: Any] {
        let requestID = UUID().uuidString
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": method,
            "params": params,
        ]
        let data = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if includeProtocolVersion {
            request.setValue(protocolVersion, forHTTPHeaderField: "MCP-Protocol-Version")
        }
        if let sessionID {
            request.setValue(sessionID, forHTTPHeaderField: "MCP-Session-Id")
        }

        let (respData, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let httpStatus = httpResponse?.statusCode

        if let sid = httpResponse?.value(forHTTPHeaderField: "MCP-Session-Id") {
            sessionID = sid
        }

        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let payload: [String: Any]
        if contentType.contains("text/event-stream") {
            guard let parsed = Self.parseSSEResult(respData, requestID: requestID) else {
                throw ClientError.invalidResponse("No JSON-RPC response in SSE stream: \(String(decoding: respData, as: UTF8.self))")
            }
            payload = parsed
        } else {
            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
                throw ClientError.invalidResponse(String(decoding: respData, as: UTF8.self))
            }
            payload = json
        }

        if let error = payload["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "(no message)"
            throw RPCError(code: code, message: message, httpStatus: httpStatus)
        }
        guard let result = payload["result"] as? [String: Any] else {
            throw ClientError.decoding("Missing `result` field: \(payload)")
        }
        return result
    }

    // MARK: - SSE parsing

    /// Walks an SSE event stream looking for a JSON-RPC message whose `id`
    /// matches the request. Returns the decoded JSON object (with `result`
    /// or `error`) once found.
    private static func parseSSEResult(_ data: Data, requestID: String) -> [String: Any]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        // Events are separated by blank lines. Within an event, lines starting
        // with "data:" carry the payload; multiple data lines join with "\n".
        for rawEvent in text.components(separatedBy: "\n\n") {
            var dataLines: [String] = []
            for line in rawEvent.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
                if trimmed.hasPrefix("data:") {
                    var rest = trimmed.dropFirst("data:".count)
                    if rest.first == " " { rest = rest.dropFirst() }
                    dataLines.append(String(rest))
                }
            }
            guard !dataLines.isEmpty else { continue }
            let payload = dataLines.joined(separator: "\n")
            guard let json = try? JSONSerialization.jsonObject(
                with: Data(payload.utf8)
            ) as? [String: Any] else { continue }
            // Match JSON-RPC id (string or numeric).
            if let idString = json["id"] as? String, idString == requestID {
                return json
            }
            if let idNum = json["id"] as? Int, String(idNum) == requestID {
                return json
            }
        }
        return nil
    }
}
