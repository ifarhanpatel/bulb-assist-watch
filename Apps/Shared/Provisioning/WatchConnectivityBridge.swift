import Foundation
import WatchConnectivity
import BulbCore

/// The sole platform wire format is Data in an active sendMessage exchange.
/// TransferUserInfo and applicationContext intentionally have no provisioning path.
enum ProvisioningWire {
    static let payload = "provisioning-v1"
    static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        [payload: try JSONEncoder().encode(value)]
    }
    static func decode<T: Decodable>(_ type: T.Type, from value: [String: Any]) throws -> T {
        guard value.count == 1, let data = value[payload] as? Data else { throw SetupFailure.interrupted }
        return try JSONDecoder().decode(type, from: data)
    }
}

/// WCSession callbacks bridge immediately into actors. State callbacks never carry credentials.
final class WatchConnectivityBridge: NSObject, WCSessionDelegate, ActiveMessageTransport, @unchecked Sendable {
    typealias Receiver = @Sendable (ProvisioningMessage) async -> ProvisioningAcknowledgement
    private let session: WCSession
    private let receiver: Receiver?
    private let onStateChange: @MainActor @Sendable () -> Void

    init(session: WCSession = .default, receiver: Receiver? = nil,
         onStateChange: @escaping @MainActor @Sendable () -> Void = {}) {
        self.session = session
        self.receiver = receiver
        self.onStateChange = onStateChange
        super.init()
        session.delegate = self
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.activate()
    }
    var isReachable: Bool { session.activationState == .activated && session.isReachable }

    func send(_ message: ProvisioningMessage) async throws -> ProvisioningAcknowledgement {
        try Task.checkCancellation()
        guard WCSession.isSupported(), isReachable else { throw SetupFailure.unreachableWatch }
        let payload: [String: Any]
        do { payload = try ProvisioningWire.encode(message) }
        catch { throw SetupFailure.interrupted }
        // A deadline/cancellation releases the waiter, while a late callback is harmless.
        let waiter = MessageReplyWaiter()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard waiter.install(continuation) else { return }
                session.sendMessage(payload, replyHandler: { reply in
                    do {
                        let acknowledgement = try ProvisioningWire.decode(ProvisioningAcknowledgement.self, from: reply)
                        guard acknowledgement.revision == message.revision else { throw SetupFailure.staleRevision }
                        waiter.finish(.success(acknowledgement))
                    } catch let failure as SetupFailure { waiter.finish(.failure(failure)) }
                    catch { waiter.finish(.failure(SetupFailure.interrupted)) }
                }, errorHandler: { _ in waiter.finish(.failure(SetupFailure.unreachableWatch)) })
                Task {
                    try? await Task.sleep(for: .seconds(15))
                    waiter.finish(.failure(SetupFailure.interrupted))
                }
            }
        } onCancel: { waiter.finish(.failure(SetupFailure.interrupted)) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in onStateChange() }
    }
    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in onStateChange() }
    }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let receiver,
              let request = try? ProvisioningWire.decode(ProvisioningMessage.self, from: message) else {
            replyHandler([:])
            return
        }
        let reply = MessageReplyHandler(replyHandler)
        Task {
            let acknowledgement = await receiver(request)
            reply.send((try? ProvisioningWire.encode(acknowledgement)) ?? [:])
        }
    }
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { Task { @MainActor in onStateChange() } }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif
}

/// WCSession's legacy callbacks lack Sendable annotations; each is invoked once behind a lock.
private final class MessageReplyHandler: @unchecked Sendable {
    private let callback: ([String: Any]) -> Void
    init(_ callback: @escaping ([String: Any]) -> Void) { self.callback = callback }
    func send(_ reply: [String: Any]) { callback(reply) }
}

final class MessageReplyWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ProvisioningAcknowledgement, any Error>?
    private var result: Result<ProvisioningAcknowledgement, any Error>?
    @discardableResult
    func install(_ continuation: CheckedContinuation<ProvisioningAcknowledgement, any Error>) -> Bool {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
            return false
        } else {
            self.continuation = continuation
            lock.unlock()
            return true
        }
    }
    func finish(_ result: Result<ProvisioningAcknowledgement, any Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
