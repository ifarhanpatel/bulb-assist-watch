import Foundation
import Testing
@testable import BulbCore

private let setupSnapshot = BulbSnapshot(isOn: true, brightness: try! ReportedBrightness(rawValue: 620), observedAt: Date(timeIntervalSince1970: 1))
private let setupDevice = SelectedDevice(id: "fixture-bulb", name: "Fixture bulb")
private func configuration(_ revision: UInt64, key: String = "fixture-key") -> ProvisionedConfiguration {
    ProvisionedConfiguration(revision: revision, device: setupDevice, apiKey: key)
}

private actor ScriptedMessaging: ActiveMessageTransport {
    var messages: [ProvisioningMessage] = []
    var replies: [ProvisioningResult]
    var wrongRevision = false
    var unreachable = false
    var held = false
    var continuation: CheckedContinuation<ProvisioningAcknowledgement, any Error>?
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []
    init(replies: [ProvisioningResult] = [.persisted, .connected(setupSnapshot)], held: Bool = false) {
        self.replies = replies; self.held = held
    }
    func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement {
        messages.append(message)
        for observer in observers where messages.count >= observer.0 { observer.1.resume() }
        observers.removeAll { messages.count >= $0.0 }
        if unreachable { throw SetupFailure.unreachableWatch }
        if held {
            held = false
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        let result = replies.isEmpty ? .removed : replies.removeFirst()
        return ProvisioningAcknowledgement(revision: wrongRevision ? 999 : message.revision, result: result)
    }
    func waitForMessages(_ count: Int) async {
        if messages.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }
    func finishHeld(_ result: ProvisioningResult = .persisted) {
        continuation?.resume(returning: ProvisioningAcknowledgement(revision: messages[0].revision, result: result))
        continuation = nil
    }
    func setWrongRevision() { wrongRevision = true }
    func setUnreachable(_ value: Bool) { unreachable = value }
}
private struct FailedDiscovery: BulbDiscovering {
    let failure: SetupFailure
    func listDevices() async throws -> [SelectedDevice] { throw failure }
    func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities { throw failure }
}
private struct CancelledDiscovery: BulbDiscovering {
    func listDevices() async throws -> [SelectedDevice] { throw CancellationError() }
    func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities { throw CancellationError() }
}
private struct StaleVerificationTransport: ActiveMessageTransport {
    func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement {
        if case .verify = message {
            return ProvisioningAcknowledgement(revision: message.revision + 1, result: .connected(setupSnapshot))
        }
        return ProvisioningAcknowledgement(revision: message.revision, result: .persisted)
    }
}
private actor FailedStore: CredentialStoring {
    func load() -> ProvisionedConfiguration? { nil }
    func latestRevision() -> UInt64 { 0 }
    func store(_ configuration: ProvisionedConfiguration) throws { throw SetupFailure.persistence }
    func delete(revision: UInt64) throws { throw SetupFailure.persistence }
}
private actor ReadController: BulbControlling {
    var reads = 0
    let failure: BulbFailure?
    init(failure: BulbFailure? = nil) { self.failure = failure }
    func readState() async throws -> BulbSnapshot {
        reads += 1
        if let failure { throw failure }
        return setupSnapshot
    }
    func apply(_ command: BulbCommand) async throws { Issue.record("Setup must never change the lamp") }
}
private actor LifecycleEvents {
    var events: [String] = []
    func append(_ event: String) { events.append(event) }
}
private actor GatedRead: BulbControlling {
    private var readContinuation: CheckedContinuation<BulbSnapshot, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func readState() async throws -> BulbSnapshot {
        await withCheckedContinuation {
            readContinuation = $0
            observer?.resume(); observer = nil
        }
    }
    func waitForRead() async {
        if readContinuation != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() { readContinuation?.resume(returning: setupSnapshot); readContinuation = nil }
    func apply(_ command: BulbCommand) async throws { Issue.record("Unexpected write") }
}

@MainActor
struct SetupLifecycleTests {
    private func setup(store: any CredentialStoring = MemoryCredentialStore(), messaging: any ActiveMessageTransport = ScriptedMessaging(), supported: Bool = true) -> CompanionSetup {
        CompanionSetup(store: store, messaging: messaging) { _ in FixtureDiscovery(devices: [setupDevice], supported: supported) }
    }
    private func connect(_ setup: CompanionSetup) async {
        await setup.discover(apiKey: "fixture-key")
        await setup.select(setupDevice)
    }

    @Test func invalidKeyDoesNotDiscoverOrPersist() async throws {
        let store = MemoryCredentialStore()
        let setup = setup(store: store)
        for key in ["", "   ", "fixture key", "fixture\u{00}key"] {
            await setup.discover(apiKey: key)
            #expect(setup.failure == .invalidKey)
            #expect(setup.stage == .keyEntry)
        }
        #expect(await store.load() == nil)
    }
    @Test func authenticationAndDiscoveryErrorsAreActionable() async {
        let setup = CompanionSetup(store: MemoryCredentialStore(), messaging: ScriptedMessaging()) { _ in FailedDiscovery(failure: .invalidKey) }
        await setup.discover(apiKey: "fixture-key")
        #expect(setup.failure == .invalidKey)
        #expect(setup.stage == .keyEntry)
        let network = CompanionSetup(store: MemoryCredentialStore(), messaging: ScriptedMessaging()) { _ in FailedDiscovery(failure: .discovery) }
        await network.discover(apiKey: "fixture-key")
        #expect(network.failure == .discovery)
    }
    @Test func emptyDevicesPermitAnotherKey() async {
        let setup = CompanionSetup(store: MemoryCredentialStore(), messaging: ScriptedMessaging()) { _ in FixtureDiscovery(devices: []) }
        await setup.discover(apiKey: "fixture-key")
        #expect(setup.stage == .selection)
        #expect(setup.devices.isEmpty)
        setup.cancelReplacement()
        #expect(setup.stage == .keyEntry)
    }
    @Test func cancelledDiscoveryRetainsNoCandidateOrCredential() async {
        let store = MemoryCredentialStore()
        let messaging = ScriptedMessaging()
        let setup = CompanionSetup(store: store, messaging: messaging) { _ in CancelledDiscovery() }
        await setup.discover(apiKey: "fixture-key")
        #expect(setup.failure == .interrupted)
        #expect(setup.stage == .keyEntry)
        #expect(await store.load() == nil)
        #expect(await messaging.messages.isEmpty)
    }
    @Test func staleVerificationCannotReportConnectedAfterPersistence() async {
        let setup = setup(messaging: StaleVerificationTransport())
        await connect(setup)
        #expect(setup.watchPersisted)
        #expect(setup.failure == .staleRevision)
        #expect(setup.stage == .awaitingWatch)
    }
    @Test func removalRequiresDeletionReplyAndMatchingRevision() async {
        for wrongRevision in [false, true] {
            let store = MemoryCredentialStore(configuration: configuration(1))
            let messaging = ScriptedMessaging(replies: [wrongRevision ? .removed : .persisted])
            if wrongRevision { await messaging.setWrongRevision() }
            let setup = setup(store: store, messaging: messaging)
            await setup.restore()
            await setup.remove()
            #expect(setup.stage == .pendingRemoval)
            #expect(setup.failure == (wrongRevision ? .staleRevision : .interrupted))
            #expect(await store.load() == nil)
        }
    }
    @Test func unsupportedDeviceNeverPersistsOrMessages() async {
        let store = MemoryCredentialStore()
        let messaging = ScriptedMessaging()
        let setup = setup(store: store, messaging: messaging, supported: false)
        await connect(setup)
        #expect(setup.failure == .unsupportedDevice)
        #expect(await store.load() == nil)
        #expect(await messaging.messages.isEmpty)
    }
    @Test func persistenceFailureNeverProvisionsWatch() async {
        let messaging = ScriptedMessaging()
        let setup = setup(store: FailedStore(), messaging: messaging)
        await connect(setup)
        #expect(setup.failure == .persistence)
        #expect(await messaging.messages.isEmpty)
    }
    @Test func connectionRequiresPersistedThenSeparateDirectRead() async {
        let messaging = ScriptedMessaging(replies: [.persisted, .failed(.bulb(.offline))])
        let setup = setup(messaging: messaging)
        await connect(setup)
        #expect(setup.watchPersisted)
        #expect(setup.stage == .awaitingWatch)
        #expect(setup.failure == .bulb(.offline))
        #expect(await messaging.messages == [.provision(configuration(1)), .verify(revision: 1)])
    }
    @Test func prematureConnectedReplyCannotPassPersistenceGate() async {
        let messaging = ScriptedMessaging(replies: [.connected(setupSnapshot)])
        let setup = setup(messaging: messaging)
        await connect(setup)
        #expect(!setup.watchPersisted)
        #expect(setup.failure == .interrupted)
        #expect(await messaging.messages.count == 1)
    }
    @Test func staleAcknowledgementCannotPassPersistenceGate() async {
        let messaging = ScriptedMessaging()
        await messaging.setWrongRevision()
        let setup = setup(messaging: messaging)
        await connect(setup)
        #expect(setup.failure == .staleRevision)
        #expect(!setup.watchPersisted)
    }
    @Test func unreachableWatchRetainsSavedRevisionForRelaunchRetry() async throws {
        let store = MemoryCredentialStore()
        let messaging = ScriptedMessaging()
        await messaging.setUnreachable(true)
        let first = setup(store: store, messaging: messaging)
        await connect(first)
        #expect(first.stage == .awaitingWatch)
        #expect(first.failure == .unreachableWatch)
        #expect(await store.latestRevision() == 1)
        let relaunched = setup(store: store, messaging: messaging)
        await relaunched.restore()
        #expect(relaunched.stage == .awaitingWatch)
        #expect(!relaunched.watchPersisted)
        await messaging.setUnreachable(false)
        await relaunched.retryDelivery()
        if case .connected = relaunched.stage {} else { Issue.record("Direct read required after relaunch") }
        #expect(await store.latestRevision() == 1)
    }
    @Test func interruptionRetainsPendingConfiguration() async {
        let setup = setup(messaging: ScriptedMessaging(replies: [.failed(.interrupted)]))
        await connect(setup)
        #expect(setup.stage == .awaitingWatch)
        #expect(setup.hasSavedConfiguration)
        #expect(setup.failure == .interrupted)
    }
    @Test func replacementRevalidatesAndIncreasesRevision() async throws {
        let store = MemoryCredentialStore(configuration: configuration(4))
        let messaging = ScriptedMessaging()
        let setup = setup(store: store, messaging: messaging)
        await setup.restore()
        setup.beginReplacement()
        #expect(setup.isReplacing)
        await setup.discover(apiKey: "fixture-new-key")
        #expect(await store.load() == configuration(4))
        await setup.select(setupDevice)
        #expect(await store.load() == configuration(5, key: "fixture-new-key"))
        #expect(!setup.isReplacing)
        #expect(await messaging.messages == [.provision(configuration(5, key: "fixture-new-key")), .verify(revision: 5)])
    }
    @Test func invalidReplacementPreservesExistingCredential() async {
        let store = MemoryCredentialStore(configuration: configuration(4))
        let setup = setup(store: store)
        await setup.restore()
        setup.beginReplacement()
        await setup.discover(apiKey: "")
        #expect(await store.load() == configuration(4))
        setup.cancelReplacement()
        #expect(setup.stage == .awaitingWatch)
    }
    @Test func removalPersistsTombstoneBeforeDeliveryAndResumesAfterRelaunch() async throws {
        let store = MemoryCredentialStore(configuration: configuration(2))
        let messaging = ScriptedMessaging(replies: [.removed])
        await messaging.setUnreachable(true)
        let setup = setup(store: store, messaging: messaging)
        await setup.restore()
        await setup.remove()
        #expect(await store.load() == nil)
        #expect(await store.latestRevision() == 3)
        #expect(setup.stage == .pendingRemoval)
        #expect(!setup.hasSavedConfiguration)
        let resumed = self.setup(store: store, messaging: messaging)
        await resumed.restore()
        #expect(resumed.stage == .pendingRemoval)
        await messaging.setUnreachable(false)
        await resumed.retryDelivery()
        #expect(resumed.stage == .removed)
        #expect(await messaging.messages == [.remove(revision: 3), .remove(revision: 3)])
    }
    @Test func lateProvisionReplyCannotRestoreRemovedConnection() async throws {
        let store = MemoryCredentialStore()
        let messaging = ScriptedMessaging(replies: [.removed], held: true)
        let setup = setup(store: store, messaging: messaging)
        await setup.discover(apiKey: "fixture-key")
        let provision = Task { await setup.select(setupDevice) }
        await messaging.waitForMessages(1)
        await setup.remove()
        #expect(setup.stage == .pendingRemoval)
        await messaging.finishHeld()
        await provision.value
        #expect(!setup.hasSavedConfiguration)
        #expect(!setup.watchPersisted)
        #expect(setup.stage == .pendingRemoval)
        await setup.retryDelivery()
        #expect(setup.stage == .removed)
        #expect(await messaging.messages == [.provision(configuration(1)), .remove(revision: 2)])
    }
    @Test func removalFailureKeepsPhoneConfiguration() async {
        let setup = setup(store: FailedStore())
        await setup.remove()
        #expect(setup.failure == .persistence)
    }
    @Test func receiverPersistsBeforeAckAndReadsOnlyOnVerify() async {
        let store = MemoryCredentialStore()
        let controller = ReadController()
        let events = LifecycleEvents()
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in controller }, invalidate: { await events.append("invalidate") }, configurationChanged: { configuration in
            #expect(await store.load() == configuration)
            await events.append("stored")
        })
        let reply = await receiver.receive(.provision(configuration(1)))
        #expect(reply.result == .persisted)
        #expect(await controller.reads == 0)
        #expect(await events.events == ["invalidate", "stored"])
        #expect(await receiver.receive(.verify(revision: 1)).result == .connected(setupSnapshot))
        #expect(await controller.reads == 1)
    }
    @Test func duplicateReplayIsIdempotentButConflictsAndStaleMessagesFail() async {
        let store = MemoryCredentialStore()
        let events = LifecycleEvents()
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in ReadController() }, invalidate: { await events.append("invalidate") })
        #expect(await receiver.receive(.provision(configuration(1))).result == .persisted)
        #expect(await receiver.receive(.provision(configuration(1))).result == .persisted)
        #expect(await events.events.count == 1)
        #expect(await receiver.receive(.provision(configuration(1, key: "other-fixture"))).result == .failed(.staleRevision))
        #expect(await receiver.receive(.remove(revision: 1)).result == .failed(.staleRevision))
        #expect(await receiver.receive(.remove(revision: 2)).result == .removed)
        #expect(await receiver.receive(.remove(revision: 2)).result == .removed)
        #expect(await receiver.receive(.provision(configuration(1))).result == .failed(.staleRevision))
        #expect(await receiver.receive(.provision(configuration(2))).result == .failed(.staleRevision))
        #expect(await receiver.receive(.verify(revision: 2)).result == .failed(.staleRevision))
        #expect(await events.events.count == 2)
    }
    @Test func receiverPersistenceFailureIsNeverAcknowledged() async {
        let receiver = ProvisioningReceiver(store: FailedStore(), controllerFactory: { _ in ReadController() })
        #expect(await receiver.receive(.provision(configuration(1))).result == .failed(.persistence))
        #expect(await receiver.receive(.remove(revision: 1)).result == .failed(.persistence))
    }
    @Test func receiverDirectReadErrorsRemainDistinct() async {
        let store = MemoryCredentialStore(configuration: configuration(1))
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in ReadController(failure: .authentication) })
        #expect(await receiver.receive(.verify(revision: 1)).result == .failed(.bulb(.authentication)))
        #expect(await receiver.receive(.verify(revision: 3)).result == .failed(.staleRevision))
    }
    @Test func receiverSerializesDirectReadAndRemoval() async {
        let store = MemoryCredentialStore(configuration: configuration(1))
        let controller = GatedRead()
        let events = LifecycleEvents()
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in controller }, invalidate: { await events.append("invalidate") })
        let verification = Task { await receiver.receive(.verify(revision: 1)) }
        await controller.waitForRead()
        let removal = Task { await receiver.receive(.remove(revision: 2)) }
        #expect(await store.load() == configuration(1))
        await controller.finish()
        #expect(await verification.value.result == .connected(setupSnapshot))
        #expect(await removal.value.result == .removed)
        #expect(await store.load() == nil)
        #expect(await events.events == ["invalidate"])
        #expect(await receiver.receive(.verify(revision: 1)).result == .failed(.staleRevision))
    }
    @Test func tombstoneSurvivesReceiverRelaunchAndNewSetupUsesNextRevision() async throws {
        let store = MemoryCredentialStore(configuration: configuration(1))
        try await store.delete(revision: 2)
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in ReadController() })
        #expect(await receiver.receive(.provision(configuration(1))).result == .failed(.staleRevision))
        let setup = setup(store: store, messaging: LoopbackMessageTransport(receiver: receiver))
        await setup.restore()
        await setup.retryDelivery()
        setup.startAgain()
        await connect(setup)
        #expect(await store.latestRevision() == 3)
    }
}
