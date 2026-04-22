//
//  MCPIntegrationTests.swift
//  ArgoTradingSwiftUITests
//
//  Drives the embedded MCP server over HTTP. Each test copies the MCP test
//  fixture to a temp location, launches the app with a pinned port, then calls
//  the tools through `MCPTestClient`.
//

import XCTest

@MainActor
final class MCPIntegrationTests: XCTestCase {
    /// Picks a fresh port per test so concurrent runs don't clash.
    private let basePort = 44321
    private var testPort: Int = 0

    override func setUp() {
        super.setUp()
        // Spread across test methods to avoid collisions within a single run.
        testPort = basePort + Int.random(in: 0 ..< 100)
    }

    // MARK: - Fixture setup

    private func prepareFixture() throws -> URL {
        let source = UITestUtils.testProjectURL(name: "MCP Test project")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: source.path),
            "Fixture missing at \(source.path)"
        )
        let sourceDir = source.deletingLastPathComponent()
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("argo-mcp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // Copy fixture + required subfolders (data/, strategy/, result/ empty).
        try FileManager.default.copyItem(at: source, to: destDir.appendingPathComponent(source.lastPathComponent))
        for sub in ["data", "strategy"] {
            let src = sourceDir.appendingPathComponent(sub)
            if FileManager.default.fileExists(atPath: src.path) {
                try FileManager.default.copyItem(at: src, to: destDir.appendingPathComponent(sub))
            }
        }
        for sub in ["result", "trading"] {
            try FileManager.default.createDirectory(
                at: destDir.appendingPathComponent(sub),
                withIntermediateDirectories: true
            )
        }
        return destDir.appendingPathComponent(source.lastPathComponent)
    }

    private func launchApp(fixture: URL, port: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            fixture.path,
            "-ArgoDisableUpdates",
            "-ArgoResetState",
            "-ArgoMcpPort", String(port),
        ]
        app.launchEnvironment["ARGO_DISABLE_UPDATES"] = "1"
        app.launchEnvironment["ARGO_RESET_STATE"] = "1"
        app.launchEnvironment["ARGO_MCP_PORT"] = String(port)
        app.launch()
        return app
    }

    // MARK: - Tests

    func testListToolsReturnsAllTools() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()
        let names = Set(try await client.listTools())

        let expected: Set<String> = [
            "load_strategy", "list_schemas", "read_schema", "update_schema",
            "list_data", "select_schema", "select_data", "run_backtest", "get_config",
            "get_backtest_status",
        ]
        XCTAssertEqual(names, expected, "unexpected tool set: \(names)")
    }

    func testListSchemasAndReadSchema() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()

        // Wait for the document to finish registering before MCP calls mutate it.
        try await waitForDocument(client: client)

        let list = try await client.callTool("list_schemas", arguments: ["limit": 10])
        let structured = list["structuredContent"] as? [String: Any]
        let schemas = structured?["schemas"] as? [[String: Any]]
        XCTAssertNotNil(schemas, "list_schemas missing schemas: \(list)")
        XCTAssertEqual(schemas?.count, 1)
        let schemaID = schemas?.first?["id"] as? String
        XCTAssertNotNil(schemaID)

        let read = try await client.callTool("read_schema", arguments: ["schema_id": schemaID!])
        let readStructured = read["structuredContent"] as? [String: Any]
        XCTAssertEqual(readStructured?["strategy_path"] as? String, "place_order_plugin.wasm")
        let backtestConfig = readStructured?["backtest_config"] as? [String: Any]
        XCTAssertEqual(backtestConfig?["broker"] as? String, "IBKR")
    }

    func testSelectSchemaAndDataUpdatesGetConfig() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()
        try await waitForDocument(client: client)

        let list = try await client.callTool("list_schemas", arguments: ["limit": 10])
        let schemaID = ((list["structuredContent"] as? [String: Any])?["schemas"] as? [[String: Any]])?
            .first?["id"] as? String
        XCTAssertNotNil(schemaID)

        let data = try await client.callTool("list_data", arguments: [:])
        let datasets = (data["structuredContent"] as? [String: Any])?["datasets"] as? [[String: Any]]
        let dataID = datasets?.first?["id"] as? String
        XCTAssertNotNil(dataID)

        _ = try await client.callTool("select_schema", arguments: ["schema_id": schemaID!])
        _ = try await client.callTool("select_data", arguments: ["data_id": dataID!])

        let config = try await client.callTool("get_config", arguments: [:])
        let cs = config["structuredContent"] as? [String: Any]
        let sel = cs?["selected_schema"] as? [String: Any]
        XCTAssertEqual(sel?["id"] as? String, schemaID)
        let dsel = cs?["selected_dataset"] as? [String: Any]
        XCTAssertEqual(dsel?["id"] as? String, dataID)
    }

    func testLoadStrategyRejectsNonWasm() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()
        try await waitForDocument(client: client)

        // Create a throwaway non-wasm file.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("bogus.txt")
        try? "not a wasm file".write(to: tmp, atomically: true, encoding: .utf8)

        let result = try await client.callTool("load_strategy", arguments: ["strategy_path": tmp.path])
        XCTAssertEqual(result["isError"] as? Bool, true, "expected isError: \(result)")
    }

    func testLoadStrategyCopiesWasmIntoProject() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()
        try await waitForDocument(client: client)

        // Use the existing fixture wasm as a "new" strategy with a different name.
        let sourceWasm = fixture.deletingLastPathComponent().appendingPathComponent("strategy/place_order_plugin.wasm")
        let renamed = FileManager.default.temporaryDirectory.appendingPathComponent("renamed_strategy.wasm")
        try? FileManager.default.removeItem(at: renamed)
        try FileManager.default.copyItem(at: sourceWasm, to: renamed)

        let result = try await client.callTool("load_strategy", arguments: ["strategy_path": renamed.path])
        XCTAssertNotEqual(result["isError"] as? Bool, true, "expected success: \(result)")

        let destination = fixture.deletingLastPathComponent().appendingPathComponent("strategy/renamed_strategy.wasm")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "wasm not copied to \(destination.path)")
    }

    func testUpdateSchemaPersistsThroughReadSchema() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady()
        try await waitForDocument(client: client)

        let list = try await client.callTool("list_schemas", arguments: ["limit": 10])
        let schemaID = ((list["structuredContent"] as? [String: Any])?["schemas"] as? [[String: Any]])?
            .first?["id"] as? String
        XCTAssertNotNil(schemaID)

        let newParams: [String: Any] = ["Symbol": "ETHUSDT"]
        let upd = try await client.callTool("update_schema", arguments: [
            "schema_id": schemaID!,
            "strategy_config": newParams,
        ])
        XCTAssertNotEqual(upd["isError"] as? Bool, true, "update_schema reported error: \(upd)")

        let read = try await client.callTool("read_schema", arguments: ["schema_id": schemaID!])
        let cfg = (read["structuredContent"] as? [String: Any])?["strategy_config"] as? [String: Any]
        XCTAssertEqual(cfg?["Symbol"] as? String, "ETHUSDT")
    }

    func testRunBacktestProducesResultFolder() async throws {
        let fixture = try prepareFixture()
        _ = launchApp(fixture: fixture, port: testPort)

        let client = MCPTestClient(port: testPort)
        try await client.waitUntilReady(timeout: 60)
        try await waitForDocument(client: client)

        // The fixture already has a selected schema + dataset, so just run.
        let result = try await client.callTool("run_backtest", arguments: [:])
        XCTAssertNotEqual(result["isError"] as? Bool, true, "run_backtest reported error: \(result)")

        let structured = result["structuredContent"] as? [String: Any]
        guard let resultPath = structured?["result_path"] as? String else {
            XCTFail("run_backtest did not return result_path: \(result)")
            return
        }
        // Each backtest run creates a fresh timestamped folder under result/ —
        // that folder (not its grandparent) is what the tool returns.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: resultPath),
            "result_path does not exist: \(resultPath)"
        )
        // Find a stats.yaml somewhere under the run folder.
        let enumerator = FileManager.default.enumerator(atPath: resultPath)
        let foundStats = (enumerator?.allObjects as? [String])?.contains { $0.hasSuffix("stats.yaml") } ?? false
        XCTAssertTrue(foundStats, "no stats.yaml found under \(resultPath)")
    }

    // MARK: - Helpers

    /// Poll `list_schemas` until the document has registered (HomeView.onAppear
    /// fires a moment after launch). Returns once we get a non-error response.
    private func waitForDocument(client: MCPTestClient, timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let r = try await client.callTool("list_schemas", arguments: ["limit": 1])
            if (r["isError"] as? Bool) != true { return }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("Document never registered within \(Int(timeout))s")
    }
}
