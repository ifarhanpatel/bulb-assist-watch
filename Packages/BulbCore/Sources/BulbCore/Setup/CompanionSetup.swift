import Foundation
import Observation

public enum SetupStage: Equatable, Sendable {
    case keyEntry, discovering, selection, validating, saving
    case awaitingWatch, verifyingWatch, connected(BulbSnapshot)
    case pendingRemoval, removed
}

/// Phone setup state. Credentials stay private to this coordinator and its injected store.
/// Relaunch always rechecks Watch persistence and then reads directly; connection is never inferred.
@MainActor @Observable
public final class CompanionSetup {
    public typealias DiscoveryFactory = @Sendable (String) throws -> any BulbDiscovering
    public private(set) var stage: SetupStage = .keyEntry
    public private(set) var devices: [SelectedDevice] = []
    public private(set) var selectedDevice: SelectedDevice?
    public private(set) var failure: SetupFailure?
    public private(set) var isReplacing = false
    public private(set) var hasSavedConfiguration = false
    public private(set) var watchPersisted = false

    @ObservationIgnored private let store: any CredentialStoring
    @ObservationIgnored private let messaging: any ActiveMessageTransport
    @ObservationIgnored private let discoveryFactory: DiscoveryFactory
    @ObservationIgnored private var discovery: (any BulbDiscovering)?
    @ObservationIgnored private var candidateKey: String?
    @ObservationIgnored private var saved: ProvisionedConfiguration?
    @ObservationIgnored private var pendingRemovalRevision: UInt64?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var sending = false

    public init(store: any CredentialStoring, messaging: any ActiveMessageTransport,
                discoveryFactory: @escaping DiscoveryFactory) {
        self.store = store; self.messaging = messaging; self.discoveryFactory = discoveryFactory
    }

    public var isBusy: Bool {
        switch stage {
        case .discovering, .validating, .saving, .verifyingWatch: true
        default: sending
        }
    }

    public func restore() async {
        guard !isBusy else { return }
        generation &+= 1
        let operation = generation
        do {
            let configuration = try await store.load()
            let revision = try await store.latestRevision()
            guard operation == generation else { return }
            saved = configuration
            selectedDevice = configuration?.device
            hasSavedConfiguration = configuration != nil
            failure = nil
            watchPersisted = false
            if configuration != nil {
                stage = .awaitingWatch
            } else if revision > 0 {
                pendingRemovalRevision = revision
                stage = .pendingRemoval
            } else {
                stage = .keyEntry
            }
        } catch { fail(error, fallback: .persistence) }
    }

    public func beginReplacement() {
        guard !isBusy, saved != nil else { return }
        generation &+= 1
        isReplacing = true
        candidateKey = nil
        discovery = nil
        devices = []
        failure = nil
        stage = .keyEntry
    }

    public func cancelReplacement() {
        guard !isBusy else { return }
        generation &+= 1
        candidateKey = nil
        discovery = nil
        devices = []
        isReplacing = false
        failure = nil
        stage = saved == nil ? .keyEntry : .awaitingWatch
    }

    public func discover(apiKey: String) async {
        guard !isBusy else { return }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains(where: { $0.isWhitespace || $0.isNewline }),
              !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            failure = .invalidKey
            stage = .keyEntry
            return
        }
        generation &+= 1
        let operation = generation
        failure = nil
        stage = .discovering
        do {
            let client = try discoveryFactory(key)
            let found = try await client.listDevices()
            try Task.checkCancellation()
            guard operation == generation else { return }
            candidateKey = key
            discovery = client
            devices = found
            stage = .selection
        } catch {
            guard operation == generation else { return }
            candidateKey = nil
            discovery = nil
            stage = .keyEntry
            fail(error, fallback: .discovery)
        }
    }

    public func select(_ device: SelectedDevice) async {
        guard !isBusy, devices.contains(device), let discovery, let candidateKey else { return }
        let operation = generation
        failure = nil
        stage = .validating
        do {
            guard try await discovery.capabilities(for: device).isSupported else { throw SetupFailure.unsupportedDevice }
            try Task.checkCancellation()
            guard operation == generation else { return }
            stage = .saving
            let latest = try await store.latestRevision()
            guard latest < UInt64.max else { throw SetupFailure.persistence }
            let configuration = ProvisionedConfiguration(revision: latest + 1, device: device, apiKey: candidateKey)
            try await store.store(configuration)
            guard operation == generation else { return }
            saved = configuration
            selectedDevice = device
            hasSavedConfiguration = true
            pendingRemovalRevision = nil
            self.candidateKey = nil
            self.discovery = nil
            isReplacing = false
            watchPersisted = false
            stage = .awaitingWatch
            await retryDelivery()
        } catch {
            guard operation == generation else { return }
            stage = .selection
            fail(error, fallback: .persistence)
        }
    }

    /// Idempotent resending survives an interrupted active-message exchange and relaunch.
    public func retryDelivery() async {
        guard !isBusy else { return }
        let operation = generation
        sending = true
        failure = nil
        defer { sending = false }
        do {
            if let revision = pendingRemovalRevision {
                stage = .pendingRemoval
                let acknowledgement = try await messaging.send(.remove(revision: revision))
                guard operation == generation else { return }
                try validate(acknowledgement, revision: revision, expected: .removed)
                pendingRemovalRevision = nil
                stage = .removed
            } else if let saved {
                stage = .awaitingWatch
                let acknowledgement = try await messaging.send(.provision(saved))
                guard operation == generation else { return }
                try validate(acknowledgement, revision: saved.revision, expected: .persisted)
                watchPersisted = true
                stage = .verifyingWatch
                let verification = try await messaging.send(.verify(revision: saved.revision))
                guard operation == generation else { return }
                guard verification.revision == saved.revision else { throw SetupFailure.staleRevision }
                switch verification.result {
                case .connected(let snapshot):
                    guard snapshot.isOnline else { throw SetupFailure.bulb(.offline) }
                    stage = .connected(snapshot)
                case .failed(let failure): throw failure
                default: throw SetupFailure.interrupted
                }
            }
        } catch {
            guard operation == generation else { return }
            stage = pendingRemovalRevision == nil ? .awaitingWatch : .pendingRemoval
            fail(error, fallback: .unreachableWatch)
        }
    }

    /// Removes the phone credential first, then requires a durable Watch deletion acknowledgement.
    public func remove() async {
        if pendingRemovalRevision != nil { await retryDelivery(); return }
        guard stage != .saving, stage != .validating, stage != .discovering else { return }
        // Allow removal to supersede an in-flight provision/verification. Generation guards ignore its reply.
        generation &+= 1
        let operation = generation
        failure = nil
        candidateKey = nil
        discovery = nil
        stage = .saving
        do {
            let latest = try await store.latestRevision()
            guard latest < UInt64.max else { throw SetupFailure.persistence }
            let revision = latest + 1
            try await store.delete(revision: revision)
            guard operation == generation else { return }
            saved = nil
            selectedDevice = nil
            hasSavedConfiguration = false
            watchPersisted = false
            isReplacing = false
            pendingRemovalRevision = revision
            stage = .pendingRemoval
            // A still-running exchange owns `sending`; its stale completion cannot restore configuration.
            if !sending { await retryDelivery() }
        } catch {
            guard operation == generation else { return }
            stage = saved == nil ? .keyEntry : .awaitingWatch
            fail(error, fallback: .persistence)
        }
    }

    public func startAgain() {
        guard !isBusy, !hasSavedConfiguration, stage == .removed else { return }
        generation &+= 1
        failure = nil
        devices = []
        stage = .keyEntry
    }

    private func validate(_ acknowledgement: ProvisioningAcknowledgement, revision: UInt64,
                          expected: ProvisioningResult) throws {
        guard acknowledgement.revision == revision else { throw SetupFailure.staleRevision }
        if case .failed(let failure) = acknowledgement.result { throw failure }
        guard acknowledgement.result == expected else { throw SetupFailure.interrupted }
    }
    private func fail(_ error: any Error, fallback: SetupFailure) {
        if let setup = error as? SetupFailure { failure = setup }
        else if let bulb = error as? BulbFailure { failure = bulb == .authentication ? .invalidKey : .bulb(bulb) }
        else if error is CancellationError { failure = .interrupted }
        else { failure = fallback }
    }
}
