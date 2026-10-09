import BulbCore
import Foundation
import Observation

@MainActor @Observable
final class CompanionRuntime {
    let setup: CompanionSetup
    @ObservationIgnored private var bridge: WatchConnectivityBridge?
    @ObservationIgnored private let deliveryLink: SetupDeliveryLink

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let deliveryLink = SetupDeliveryLink()
        self.deliveryLink = deliveryLink
        if arguments.contains("--fixture-setup") {
            let phoneStore = MemoryCredentialStore()
            let watchStore = MemoryCredentialStore()
            let receiver = ProvisioningReceiver(store: watchStore, controllerFactory: { _ in
                SimulatedBulbController(latency: .zero)
            })
            let transport: any ActiveMessageTransport = arguments.contains("--fixture-unreachable")
                ? UnreachableFixtureTransport() : LoopbackMessageTransport(receiver: receiver)
            setup = CompanionSetup(store: phoneStore, messaging: transport, discoveryFactory: { _ in FixtureDiscovery() })
        } else {
            let bridge = WatchConnectivityBridge(onStateChange: { [weak deliveryLink] in deliveryLink?.changed() })
            self.bridge = bridge
            setup = CompanionSetup(store: KeychainCredentialStore(), messaging: bridge, discoveryFactory: { key in
                try PacedDiscovery(discovery: TuyaDiscovery(apiKey: key))
            })
        }
        deliveryLink.setup = setup
    }
    func activate() async {
        bridge?.activate()
        await setup.restore()
        await setup.retryDelivery()
    }
}

@MainActor private final class SetupDeliveryLink {
    weak var setup: CompanionSetup?
    func changed() {
        guard let setup else { return }
        switch setup.stage {
        case .awaitingWatch, .pendingRemoval:
            Task { await setup.retryDelivery() }
        default: break
        }
    }
}

private struct UnreachableFixtureTransport: ActiveMessageTransport {
    func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement {
        throw SetupFailure.unreachableWatch
    }
}

/// Setup discovery has a separate foreground budget; adapters still perform one operation per call.
private actor PacedDiscovery: BulbDiscovering {
    private let discovery: any BulbDiscovering
    private var lastCompletion: ContinuousClock.Instant?
    init(discovery: any BulbDiscovering) { self.discovery = discovery }
    private func pace() async throws {
        if let lastCompletion {
            let remaining = Duration.seconds(1) - lastCompletion.duration(to: .now)
            if remaining > .zero { try await Task.sleep(for: remaining) }
        }
    }
    func listDevices() async throws -> [SelectedDevice] {
        try await pace()
        defer { lastCompletion = .now }
        return try await discovery.listDevices()
    }
    func capabilities(for device: SelectedDevice) async throws -> DeviceCapabilities {
        try await pace()
        defer { lastCompletion = .now }
        return try await discovery.capabilities(for: device)
    }
}

#if os(watchOS)
@MainActor @Observable
final class WatchRuntime {
    private(set) var remote: BulbRemote?
    private(set) var deviceName = "Wipro bulb"
    private(set) var failure: BulbFailure?
    private(set) var isLoading = true
    @ObservationIgnored private let store: any CredentialStoring
    @ObservationIgnored private let controllerFactory: ProvisioningReceiver.ControllerFactory

    @ObservationIgnored private var isForeground = true
    @ObservationIgnored private var revision: UInt64?
    @ObservationIgnored private var loadingRevision: UInt64?
    @ObservationIgnored private var configurationTask: Task<Void, Never>?
    @ObservationIgnored private lazy var receiver = ProvisioningReceiver(
        store: store,
        controllerFactory: { [weak self] configuration in
            guard let self else { throw SetupFailure.interrupted }
            await self.configure(configuration)
            return await WatchVerificationProxy(runtime: self, revision: configuration.revision)
        },
        invalidate: { [weak self] in await self?.invalidate() },
        configurationChanged: { [weak self] configuration in
            guard let self else { return }
            await self.configure(configuration)
        }
    )
    @ObservationIgnored private lazy var bridge = WatchConnectivityBridge(receiver: { [weak self] message in
        guard let self else { return ProvisioningAcknowledgement(revision: message.revision, result: .failed(.interrupted)) }
        return await self.receiver.receive(message)
    })

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("--fixture-watch") {
            store = MemoryCredentialStore(configuration: ProvisionedConfiguration(
                revision: 1, device: SelectedDevice(id: "fixture-bulb", name: "Fixture bulb"), apiKey: "fixture-watch-key"))
            controllerFactory = { _ in SimulatedBulbController(latency: .zero) }
        } else {
            store = KeychainCredentialStore()
            controllerFactory = { configuration in
                // A full live interval separates old adapter drain, model validation and first detail.
                try await Task.sleep(for: .seconds(1))
                let discovery = try TuyaDiscovery(apiKey: configuration.apiKey)
                let controller = try await discovery.makeController(for: configuration.device)
                try await Task.sleep(for: .seconds(1))
                return controller
            }
        }
    }

    func setForeground(_ active: Bool) {
        isForeground = active
        if active {
            if remote == nil { Task { await start() } }
        } else {
            configurationTask?.cancel()
            remote?.deactivate()
        }
    }

    func start() async {
        bridge.activate()
        do { await configure(try await store.load()) }
        catch { isLoading = false; failure = .failed }
    }

    private func invalidate() async {
        loadingRevision = nil
        configurationTask?.cancel()
        if let task = configurationTask { await task.value }
        configurationTask = nil
        await remote?.deactivateAndWait()
        remote = nil
        revision = nil
        failure = nil
        isLoading = false
    }

    private func configure(_ configuration: ProvisionedConfiguration?) async {
        guard isForeground else { isLoading = false; return }
        guard let configuration else { remote = nil; revision = nil; isLoading = false; return }
        if revision == configuration.revision, remote != nil { return }
        if loadingRevision == configuration.revision, let task = configurationTask {
            await task.value
            return
        }
        configurationTask?.cancel()
        if let oldTask = configurationTask { await oldTask.value }
        loadingRevision = configuration.revision
        let task = Task { [weak self] in
            guard let self else { return }
            await self.buildRemote(configuration)
        }
        configurationTask = task
        await task.value
        if loadingRevision == configuration.revision { configurationTask = nil; loadingRevision = nil }
    }

    private func buildRemote(_ configuration: ProvisionedConfiguration) async {
        isLoading = true
        failure = nil
        do {
            await remote?.deactivateAndWait()
            remote = nil
            let controller = try await controllerFactory(configuration)
            try Task.checkCancellation()
            guard loadingRevision == configuration.revision else { return }
            revision = configuration.revision
            deviceName = configuration.device.name
            remote = BulbRemote(controller: controller, policy: .live)
        } catch is CancellationError {
            remote = nil
        } catch {
            remote = nil
            failure = error as? BulbFailure ?? .failed
        }
        isLoading = false
    }

    fileprivate func verify(revision expected: UInt64) async throws -> BulbSnapshot {
        guard isForeground else { throw SetupFailure.unreachableWatch }
        if let task = configurationTask { await task.value }
        guard revision == expected, let remote else { throw failure ?? BulbFailure.missingDevice }
        await remote.activate()
        guard isForeground else { throw SetupFailure.unreachableWatch }
        guard revision == expected else { throw SetupFailure.staleRevision }
        guard remote.status == .ready, let snapshot = remote.reportedState, snapshot.isOnline else {
            switch remote.status {
            case .failed(let failure), .setupRequired(let failure): throw failure
            case .cooldown: throw BulbFailure.rateLimited(retryAfter: nil)
            default: throw BulbFailure.uncertainWrite
            }
        }
        return snapshot
    }
}

@MainActor private final class WatchVerificationProxy: BulbControlling {
    private let runtime: WatchRuntime
    private let revision: UInt64
    init(runtime: WatchRuntime, revision: UInt64) { self.runtime = runtime; self.revision = revision }
    func readState() async throws -> BulbSnapshot { try await runtime.verify(revision: revision) }
    func apply(_ command: BulbCommand) async throws { throw BulbFailure.rejected }
}
#endif
