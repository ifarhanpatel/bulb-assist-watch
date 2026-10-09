/// Handles active messages on Watch. Entire operations are serialized, including persistence
/// and direct reads, so a reply cannot race a newer replacement or removal.
public actor ProvisioningReceiver {
    public typealias ControllerFactory = @Sendable (ProvisionedConfiguration) async throws -> any BulbControlling
    public typealias Invalidation = @Sendable () async -> Void
    public typealias ConfigurationChanged = @Sendable (ProvisionedConfiguration?) async -> Void

    private let store: any CredentialStoring
    private let controllerFactory: ControllerFactory
    private let invalidate: Invalidation
    private let configurationChanged: ConfigurationChanged
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(store: any CredentialStoring, controllerFactory: @escaping ControllerFactory,
                invalidate: @escaping Invalidation = {},
                configurationChanged: @escaping ConfigurationChanged = { _ in }) {
        self.store = store
        self.controllerFactory = controllerFactory
        self.invalidate = invalidate
        self.configurationChanged = configurationChanged
    }

    public func receive(_ message: ProvisioningMessage) async -> ProvisioningAcknowledgement {
        await acquire()
        defer { release() }
        do {
            try Task.checkCancellation()
            let latest = try await store.latestRevision()
            let configuration = try await store.load()
            guard message.revision >= latest else { throw SetupFailure.staleRevision }
            let result: ProvisioningResult
            switch message {
            case .provision(let newConfiguration):
                if newConfiguration.revision == latest {
                    guard configuration == newConfiguration else { throw SetupFailure.staleRevision }
                } else {
                    await invalidate()
                    try await store.store(newConfiguration)
                    await configurationChanged(newConfiguration)
                }
                result = .persisted
            case .remove(let revision):
                if revision == latest {
                    guard configuration == nil else { throw SetupFailure.staleRevision }
                } else {
                    await invalidate()
                    try await store.delete(revision: revision)
                    await configurationChanged(nil)
                }
                result = .removed
            case .verify(let revision):
                guard revision == latest, let configuration, configuration.revision == revision else {
                    throw SetupFailure.staleRevision
                }
                let controller = try await controllerFactory(configuration)
                let snapshot = try await controller.readState()
                try Task.checkCancellation()
                guard snapshot.isOnline else { throw SetupFailure.bulb(.offline) }
                result = .connected(snapshot)
            }
            return ProvisioningAcknowledgement(revision: message.revision, result: result)
        } catch let failure as SetupFailure {
            return failureReply(message, failure)
        } catch let failure as BulbFailure {
            return failureReply(message, .bulb(failure))
        } catch is CancellationError {
            return failureReply(message, .interrupted)
        } catch {
            if case .verify = message { return failureReply(message, .bulb(.transport)) }
            return failureReply(message, .persistence)
        }
    }

    private func failureReply(_ message: ProvisioningMessage, _ failure: SetupFailure) -> ProvisioningAcknowledgement {
        ProvisioningAcknowledgement(revision: message.revision, result: .failed(failure))
    }
    private func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiters.append($0) }
    }
    private func release() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }
}

/// Active-message fixture; does not establish connection until the receiver performs a read.
public struct LoopbackMessageTransport: ActiveMessageTransport {
    public let receiver: ProvisioningReceiver
    public init(receiver: ProvisioningReceiver) { self.receiver = receiver }
    public func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement {
        await receiver.receive(message)
    }
}
