import Foundation
import Testing
@testable import BulbCore

@Suite @MainActor struct TuyaCoordinatorIntegrationTests {
    private func fixture(_ scenario: IntegratedHTTP.Scenario = .normal) async throws -> (BulbRemote, ManualBulbClock, IntegratedHTTP) {
        let clock = ManualBulbClock()
        let http = IntegratedHTTP(clock: clock, scenario: scenario)
        let discovery = try TuyaDiscovery(apiKey: "sk-INsynthetic-integration-fixture", transport: http)
        let controller = try await discovery.makeController(for: SelectedDevice(id: "fixture-bulb", name: "Fixture"))
        await clock.advance(by: 1)
        let remote = BulbRemote(controller: controller, clock: clock, policy: .live)
        await remote.activate()
        return (remote, clock, http)
    }
    private func tick(_ clock: ManualBulbClock, _ seconds: Double = 1) async {
        await settleTasks()
        await clock.advance(by: seconds)
        await settleTasks()
    }
    private func finish(_ remote: BulbRemote, _ clock: ManualBulbClock) async {
        for _ in 0..<12 {
            await tick(clock)
            if !remote.isBusy { break }
        }
        await remote.waitUntilIdle()
    }
    private func bounds(_ http: IntegratedHTTP) async {
        let starts = await http.starts
        #expect(await http.maximumConcurrent == 1)
        for (left, right) in zip(starts, starts.dropFirst()) { #expect(right.at - left.at >= 1) }
    }

    @Test func realAdapterUsesSharedBudgetAndConfirmsFinalSelection() async throws {
        let (remote, clock, http) = try await fixture()
        for value in [80.0, 10, 100, 35] { remote.selectBrightness(value) }
        let idle = Task { await remote.commitBrightness() }
        await finish(remote, clock)
        await idle.value
        #expect(remote.status == .ready)
        #expect(remote.reportedState?.brightness.rawValue == 350)
        #expect(await http.writeCount == 1)
        #expect(await http.detailCount == 2)
        await bounds(http)
    }
    @Test func realAdapterRateLimitStopsQueueUntilExplicitRead() async throws {
        let (remote, clock, http) = try await fixture(.rateLimited)
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock)
        await idle.value
        #expect(remote.status == .cooldown(until: 5))
        await remote.refresh()
        #expect(await http.detailCount == 1)
        await tick(clock, 3)
        await remote.refresh()
        #expect(remote.status == .ready)
        #expect(await http.writeCount == 1)
        await bounds(http)
    }
    @Test func realAdapterWriteTimeoutReconcilesWithoutRetriesOrReplay() async throws {
        let (remote, clock, http) = try await fixture(.writeTimeout)
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await tick(clock)
        #expect(await http.writeCount == 1)
        remote.selectBrightness(25)
        await tick(clock, 5)
        await finish(remote, clock)
        await idle.value
        #expect(await http.writeCount == 1)
        #expect(remote.selection == nil)
        #expect(remote.reportedState?.brightness.rawValue == 800)
        await bounds(http)
    }
    @Test func realAdapterDoesNotHideConfirmationRetries() async throws {
        let (remote, clock, http) = try await fixture(.stale)
        remote.selectBrightness(80)
        let idle = Task { await remote.commitBrightness() }
        await finish(remote, clock)
        await idle.value
        #expect(remote.status == .unconfirmed)
        #expect(await http.writeCount == 1)
        #expect(await http.detailCount == 3)
        await bounds(http)
    }
}

private actor IntegratedHTTP: TuyaHTTPTransport {
    enum Scenario: Sendable { case normal, rateLimited, writeTimeout, stale }
    struct Start: Sendable { let at: Double; let path: String }
    let clock: ManualBulbClock
    let scenario: Scenario
    private var brightness = 620
    private var active = 0
    private(set) var maximumConcurrent = 0
    private(set) var starts: [Start] = []
    private(set) var writeCount = 0
    private(set) var detailCount = 0
    init(clock: ManualBulbClock, scenario: Scenario) { self.clock = clock; self.scenario = scenario }
    func send(_ request: URLRequest) async throws -> TuyaHTTPResponse {
        starts.append(Start(at: await clock.now(), path: request.url!.path))
        active += 1
        maximumConcurrent = max(maximumConcurrent, active)
        defer { active -= 1 }
        if request.url!.path.hasSuffix("/model") {
            let model: [String: Any] = ["services": [["properties": [
                ["code": "switch_led", "accessMode": "rw", "typeSpec": ["type": "bool"]],
                ["code": "bright_value", "accessMode": "rw", "typeSpec": ["type": "value", "min": 10, "max": 1000, "step": 1, "scale": 0]],
                ["code": "work_mode", "accessMode": "rw", "typeSpec": ["type": "enum", "range": ["white", "colour"]]]
            ]]]]
            let encoded = String(decoding: try JSONSerialization.data(withJSONObject: model), as: UTF8.self)
            return try response(["model": encoded])
        }
        if request.httpMethod == "POST" {
            writeCount += 1
            if scenario == .rateLimited { return TuyaHTTPResponse(statusCode: 429, headers: ["Retry-After": "3"], body: Data()) }
            let outer = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: String]
            let patch = try JSONSerialization.jsonObject(with: Data(outer["properties"]!.utf8)) as! [String: Any]
            #expect(Set(patch.keys) == ["bright_value"])
            if scenario != .stale { brightness = patch["bright_value"] as! Int }
            if scenario == .writeTimeout { try await clock.sleep(for: .seconds(10)) }
            return try response([:])
        }
        detailCount += 1
        return try response(["device_id": "fixture-bulb", "online": true,
                             "properties": ["switch_led": true, "bright_value": brightness, "work_mode": "white"]])
    }
    private func response(_ result: [String: Any]) throws -> TuyaHTTPResponse {
        TuyaHTTPResponse(statusCode: 200, body: try JSONSerialization.data(withJSONObject: ["success": true, "result": result]))
    }
}
