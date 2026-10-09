import Foundation
import Synchronization
import Testing
@testable import BulbCore

struct TuyaAdapterTests {
    private func discovery(_ transport: any TuyaHTTPTransport, key: String = TuyaFixtures.key) throws -> TuyaDiscovery {
        try TuyaDiscovery(apiKey: key, transport: transport, now: { TuyaFixtures.date })
    }
    private func controller(_ transport: any TuyaHTTPTransport) async throws -> TuyaBulbController {
        try await discovery(transport).makeController(for: TuyaFixtures.device)
    }

    @Test func regionRoutingAndBearerAuthentication() async throws {
        let regions = ["AY": "openapi.tuyacn.com", "AZ": "openapi.tuyaus.com", "EU": "openapi.tuyaeu.com",
                       "IN": "openapi.tuyain.com", "UE": "openapi-ueaz.tuyaus.com", "WE": "openapi-weaz.tuyaeu.com",
                       "SG": "openapi-sg.iotbing.com"]
        for (region, host) in regions {
            let transport = TuyaFixtureTransport([TuyaFixtures.response(["devices": []])])
            let key = "sk-" + region + "-synthetic"
            #expect(try await discovery(transport, key: key).listDevices().isEmpty)
            let requests = await transport.requests
            #expect(requests.count == 1)
            let request = try #require(requests.first)
            #expect(request.url?.absoluteString == "https://" + host + "/v1.0/end-user/devices/all")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + key)
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.httpMethod == "GET")
            #expect(request.httpBody == nil)
            #expect(request.timeoutInterval == 5)
        }
    }

    @Test func invalidKeyNeverMakesRequest() async {
        let transport = TuyaFixtureTransport([])
        for key in ["", "sk-IN", "sk-XX-fixture", "sk-IN-\nfixture", "sk-IN- fixture", "sk-IN-é", String(repeating: "x", count: 4097)] {
            #expect(throws: BulbFailure.authentication) { try discovery(transport, key: key) }
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test func discoveryPreservesSelectionAndRejectsAmbiguity() async throws {
        let devices = [["device_id": "first", "name": "Same name"], ["device_id": "second", "name": "Same name"]]
        let transport = TuyaFixtureTransport([TuyaFixtures.response(["devices": devices])])
        #expect(try await discovery(transport).listDevices() == [SelectedDevice(id: "first", name: "Same name"),
                                                              SelectedDevice(id: "second", name: "Same name")])
        for result: Any in [["devices": [["device_id": "", "name": "Bulb"]]],
                            ["devices": [["device_id": "same", "name": "a"], ["device_id": "same", "name": "b"]]],
                            ["devices": ["wrong"]], ["devices": [["name": "Missing ID"]]]] {
            let invalid = TuyaFixtureTransport([TuyaFixtures.response(result)])
            await #expect(throws: BulbFailure.unsupportedSchema) { try await discovery(invalid).listDevices() }
        }
    }

    @Test func schemaValidationAndEscapedPaths() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model(stringSpec: true), TuyaFixtures.model(), TuyaFixtures.detail()])
        let adapter = try discovery(transport)
        #expect(try await adapter.capabilities(for: TuyaFixtures.device).isSupported)
        let controller = try await adapter.makeController(for: TuyaFixtures.device)
        _ = try await controller.readState()
        let requests = await transport.requests
        #expect(requests.count == 3)
        let prefix = "https://openapi.tuyain.com/v1.0/end-user/devices/synthetic%2Fbulb%20%3F%23%25%E9%9B%AA"
        #expect(requests.map { $0.url!.absoluteString } == [prefix + "/model", prefix + "/model", prefix + "/detail"])
        #expect(requests.allSatisfy { $0.url?.query == nil && $0.url?.fragment == nil })
    }

    @Test func incompatibleSchemasFailBeforeControlConstruction() async throws {
        var invalid: [TuyaHTTPResponse] = [TuyaFixtures.model(powerAccess: "ro"), TuyaFixtures.model(powerAccess: "wr"),
                                           TuyaFixtures.model(modes: ["colour"]), TuyaFixtures.model(duplicate: true),
                                           TuyaFixtures.response(["model": [:]]), TuyaFixtures.response(["model": "broken"])]
        for (field, value): (String, Any) in [("min", 0), ("max", 255), ("step", 10), ("scale", 1), ("scale", NSNull()),
                                             ("min", true), ("max", "1000"), ("step", 1.5), ("type", "string")] {
            var spec: [String: Any] = ["type": "value", "min": 10, "max": 1000, "step": 1, "scale": 0]
            spec[field] = value
            invalid.append(TuyaFixtures.model(brightness: spec))
        }
        for fixture in invalid {
            let transport = TuyaFixtureTransport([fixture])
            await #expect(throws: BulbFailure.unsupportedSchema) { try await controller(transport) }
            #expect(await transport.requests.count == 1)
        }
    }

    @Test func rawReadbackIsNotClampedAndHasObservationTime() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model(), TuyaFixtures.detail(raw: 10), TuyaFixtures.detail(raw: 99)])
        let adapter = try await controller(transport)
        let first = try await adapter.readState()
        #expect(first.brightness.rawValue == 10)
        #expect(first.brightness.percent == 1)
        #expect(first.observedAt == TuyaFixtures.date)
        #expect(try await adapter.readState().brightness.rawValue == 99)
        #expect(await transport.requests.count == 3)
    }

    @Test func strictReportedValuesAndUnknownModeFailSafely() async throws {
        let invalid = [TuyaFixtures.detail(raw: true), TuyaFixtures.detail(raw: "500"), TuyaFixtures.detail(raw: 500.5),
                       TuyaFixtures.detail(raw: 9), TuyaFixtures.detail(raw: 1001), TuyaFixtures.detail(power: 1),
                       TuyaFixtures.detail(online: "true"), TuyaFixtures.detail(mode: "unknown"),
                       TuyaFixtures.detail(mode: 1), TuyaFixtures.detail(deviceID: "different")]
        for detail in invalid {
            let transport = TuyaFixtureTransport([TuyaFixtures.model(), detail])
            let adapter = try await controller(transport)
            await #expect(throws: BulbFailure.unsupportedSchema) { try await adapter.readState() }
            #expect(await transport.requests.count == 2)
        }
    }

    @Test func explicitPatchesHaveNoReadbackRetriesOrUnrelatedProperties() async throws {
        let commands: [(BulbCommand, [String: Any])] = [
            (.powerOn(brightness: nil), ["switch_led": true]),
            (.powerOn(brightness: BrightnessSelection(percent: 50)), ["switch_led": true, "bright_value": 500]),
            (.powerOff, ["switch_led": false]),
            (.brightness(BrightnessSelection(percent: 10)), ["bright_value": 100]),
            (.brightness(BrightnessSelection(percent: 100)), ["bright_value": 1000])
        ]
        let transport = TuyaFixtureTransport([TuyaFixtures.model(), TuyaFixtures.detail()] + commands.map { _ in TuyaFixtures.response([:]) })
        let adapter = try await controller(transport)
        _ = try await adapter.readState()
        for (command, _) in commands { try await adapter.apply(command) }
        let requests = await transport.requests
        #expect(requests.count == commands.count + 2)
        for (index, pair) in commands.enumerated() {
            let request = requests[index + 2]
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString.hasSuffix("/shadow/properties/issue") == true)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            let properties = try TuyaFixtures.properties(request)
            #expect(NSDictionary(dictionary: properties) == NSDictionary(dictionary: pair.1))
            let outer = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            #expect(Set(outer.keys) == ["properties"])
            #expect(outer["properties"] is String)
        }
    }

    @Test func nonWhiteModeBlocksDimmingAndOmitsDraft() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model(), TuyaFixtures.detail(mode: "colour"), TuyaFixtures.response([:])])
        let adapter = try await controller(transport)
        #expect(try await adapter.readState().mode == .other)
        await #expect(throws: BulbFailure.unsupportedSchema) { try await adapter.apply(.brightness(BrightnessSelection(percent: 40))) }
        try await adapter.apply(.powerOn(brightness: BrightnessSelection(percent: 40)))
        let requests = await transport.requests
        #expect(requests.count == 3)
        #expect(try TuyaFixtures.properties(requests[2]).keys.sorted() == ["switch_led"])
    }

    @Test func brightnessRequiresInitialRead() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model()])
        let adapter = try await controller(transport)
        await #expect(throws: BulbFailure.unsupportedSchema) { try await adapter.apply(.brightness(BrightnessSelection(percent: 40))) }
        #expect(await transport.requests.count == 1)
    }

    @Test func offlineAndMissingDevicesHaveTypedFailures() async throws {
        let offline = TuyaFixtureTransport([TuyaFixtures.model(), TuyaFixtures.detail(online: false)])
        let adapter = try await controller(offline)
        await #expect(throws: BulbFailure.offline) { try await adapter.readState() }
        await #expect(throws: BulbFailure.offline) { try await adapter.apply(.powerOff) }
        #expect(await offline.requests.count == 2)
        let missing = TuyaFixtureTransport([TuyaFixtures.model(), TuyaFixtures.response(NSNull())])
        let other = try await controller(missing)
        await #expect(throws: BulbFailure.missingDevice) { try await other.readState() }
        let modelMissing = TuyaFixtureTransport([TuyaFixtures.response(NSNull())])
        await #expect(throws: BulbFailure.missingDevice) { try await controller(modelMissing) }
    }

    @Test func httpAndEnvelopeFailuresAreSafeAndTyped() async throws {
        let cases: [(TuyaHTTPResponse, BulbFailure)] = [
            (TuyaFixtures.response([:], status: 401), .authentication), (TuyaFixtures.response([:], status: 403), .authentication),
            (TuyaFixtures.response([:], status: 404), .missingDevice), (TuyaFixtures.response([:], status: 400), .rejected),
            (TuyaFixtures.response([:], status: 408), .timedOut),
            (TuyaFixtures.response([:], status: 503), .transport),
            (TuyaFixtures.failure("1010"), .authentication), (TuyaFixtures.failure(10010), .authentication),
            (TuyaFixtures.failure(40000901), .missingDevice), (TuyaFixtures.failure("40000903"), .unsupportedSchema),
            (TuyaFixtures.failure("10001"), .rejected), (TuyaFixtures.failure("500"), .transport)
        ]
        for (fixture, expected) in cases {
            let transport = TuyaFixtureTransport([fixture])
            do { _ = try await discovery(transport).listDevices(); Issue.record("Expected typed failure") }
            catch {
                #expect(error as? BulbFailure == expected)
                #expect(!String(describing: error).contains(TuyaFixtures.key))
                #expect(!String(describing: error).contains(TuyaFixtures.device.id))
                #expect(!String(describing: error).contains("unsafe"))
            }
            #expect(await transport.requests.count == 1)
        }
    }

    @Test func retryAfterSupportsSecondsHTTPDateAndInvalidValues() async throws {
        let headers: [(String?, TimeInterval?)] = [("12", 12), ("Tue, 14 Nov 2023 22:13:40 GMT", 20),
                                                 ("Tue, 14 Nov 2023 22:13:00 GMT", 0), ("-2", nil), ("nan", nil), (nil, nil)]
        for (value, expected) in headers {
            for status in [200, 429] {
                let fields = value.map { ["rEtRy-AfTeR": $0] } ?? [:]
                let fixture = status == 200 ? TuyaFixtures.failure(429, headers: fields) : TuyaFixtures.response([:], status: status, headers: fields)
                let transport = TuyaFixtureTransport([fixture])
                await #expect(throws: BulbFailure.rateLimited(retryAfter: expected)) { try await discovery(transport).listDevices() }
            }
        }
    }

    @Test func malformedEnvelopesAndBodiesAreRejected() async throws {
        let bodies = ["not-json", "[]", "{\"success\":1,\"result\":{}}", "{\"success\":true}", "{\"success\":\"true\",\"result\":{}}"]
        for body in bodies {
            let response = TuyaHTTPResponse(statusCode: 200, body: Data(body.utf8))
            let read = TuyaFixtureTransport([response])
            await #expect(throws: BulbFailure.unsupportedSchema) { try await discovery(read).listDevices() }
            let write = TuyaFixtureTransport([TuyaFixtures.model(), response])
            let adapter = try await controller(write)
            await #expect(throws: BulbFailure.uncertainWrite) { try await adapter.apply(.powerOff) }
        }
    }

    @Test func timeoutTransportAndCancellationClassifyIssuedWritesAsUncertain() async throws {
        let outcomes: [(TuyaFixtureTransport.Outcome, BulbFailure?)] = [(.error(.timedOut), .timedOut),
                                                                      (.error(.notConnectedToInternet), .transport), (.cancelled, nil)]
        for (outcome, readFailure) in outcomes {
            let transport = TuyaFixtureTransport(outcomes: [.response(TuyaFixtures.model()), outcome, outcome])
            let adapter = try await controller(transport)
            if let readFailure {
                await #expect(throws: readFailure) { try await adapter.readState() }
            } else { await #expect(throws: CancellationError.self) { try await adapter.readState() } }
            await #expect(throws: BulbFailure.uncertainWrite) { try await adapter.apply(.powerOff) }
            #expect(await transport.requests.count == 3)
        }
        for fixture in [TuyaFixtures.response([:], status: 503), TuyaFixtures.response([:], status: 408),
                        TuyaFixtures.failure("500"), TuyaFixtures.response(NSNull())] {
            let transport = TuyaFixtureTransport([TuyaFixtures.model(), fixture])
            let adapter = try await controller(transport)
            await #expect(throws: BulbFailure.uncertainWrite) { try await adapter.apply(.powerOff) }
            #expect(await transport.requests.count == 2)
        }
    }

    @Test func issuedTaskCancellationDrainsAndDoesNotRetry() async throws {
        for write in [false, true] {
            let transport = TuyaCancellationTransport()
            let adapter = try await controller(transport)
            let task = Task {
                if write { try await adapter.apply(.powerOff) }
                else { _ = try await adapter.readState() }
            }
            await transport.waitForOperation()
            task.cancel()
            do { try await task.value; Issue.record("Expected cancellation") }
            catch {
                if write { #expect(error as? BulbFailure == .uncertainWrite) }
                else { #expect(error is CancellationError) }
            }
            #expect(await transport.requestCount() == 2)
        }
    }

    @Test func preflightCancellationDoesNotIssueAWrite() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model()])
        let adapter = try await controller(transport)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await adapter.apply(.powerOff)
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await transport.requests.count == 1)
    }

    @Test func lateTransportSuccessCannotPublishAfterCancellation() async throws {
        for write in [false, true] {
            let transport = TuyaFixtureTransport(outcomes: [.response(TuyaFixtures.model()), .cancelAndRespond])
            let adapter = try await controller(transport)
            let operation = Task {
                if write { try await adapter.apply(.powerOff) }
                else { _ = try await adapter.readState() }
            }
            do { try await operation.value; Issue.record("Expected cancelled outcome") }
            catch {
                if write { #expect(error as? BulbFailure == .uncertainWrite) }
                else { #expect(error is CancellationError) }
            }
            #expect(await transport.requests.count == 2)
        }
    }

    @Test func knownWriteRejectionsRemainCertainWithoutRetries() async throws {
        let cases: [(TuyaHTTPResponse, BulbFailure)] = [
            (TuyaFixtures.response([:], status: 401), .authentication),
            (TuyaFixtures.failure("10001"), .rejected),
            (TuyaFixtures.failure("40000901"), .missingDevice),
            (TuyaFixtures.response([:], status: 429, headers: ["Retry-After": "3"]), .rateLimited(retryAfter: 3))
        ]
        for (response, expected) in cases {
            let transport = TuyaFixtureTransport([TuyaFixtures.model(), response])
            let adapter = try await controller(transport)
            await #expect(throws: expected) { try await adapter.apply(.powerOff) }
            #expect(!expected.requiresReconciliation)
            #expect(await transport.requests.count == 2)
        }
    }

    @Test func oversizedResponseAndInvalidDeviceIDsFailSafely() async throws {
        let response = TuyaHTTPResponse(statusCode: 200, body: Data(repeating: 32, count: 2_000_001))
        let transport = TuyaFixtureTransport([response])
        await #expect(throws: BulbFailure.unsupportedSchema) { try await discovery(transport).listDevices() }
        let noRequests = TuyaFixtureTransport([])
        for id in ["", ".", ".."] {
            await #expect(throws: BulbFailure.missingDevice) {
                try await discovery(noRequests).makeController(for: SelectedDevice(id: id, name: "Fixture"))
            }
        }
        #expect(await noRequests.requests.isEmpty)
    }

    @Test func redirectsAreRejectedWithoutForwardingCredentials() async throws {
        for status in [301, 302, 303, 307, 308] {
            let transport = TuyaFixtureTransport([TuyaFixtures.response([:], status: status, headers: ["Location": "https://example.invalid/steal"])])
            await #expect(throws: BulbFailure.rejected) { try await discovery(transport).listDevices() }
            #expect(await transport.requests.count == 1)
        }
        let forwarded = Mutex<Bool?>(nil)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let destination = URLRequest(url: URL(string: "https://example.invalid/redirect")!)
        let response = HTTPURLResponse(url: URL(string: "https://openapi.tuyain.com")!, statusCode: 302,
                                       httpVersion: nil, headerFields: ["Location": destination.url!.absoluteString])!
        TuyaNoRedirectDelegate().urlSession(session, task: session.dataTask(with: destination),
                                            willPerformHTTPRedirection: response, newRequest: destination) { proposed in
            forwarded.withLock { $0 = proposed != nil }
        }
        #expect(forwarded.withLock { $0 } == false)
    }

    @Test func descriptionsNeverContainCredentialsOrDeviceIdentifiers() async throws {
        let transport = TuyaFixtureTransport([TuyaFixtures.model()])
        let discovery = try discovery(transport)
        let adapter = try await discovery.makeController(for: TuyaFixtures.device)
        for text in [String(describing: discovery), String(reflecting: discovery), String(describing: adapter), String(reflecting: adapter)] {
            #expect(!text.contains(TuyaFixtures.key))
            #expect(!text.contains(TuyaFixtures.device.id))
        }
    }
}
