import XCTest
import Foundation
import Security
import BulbCore
@testable import BulbAssist

@MainActor
final class ProvisioningPlatformTests: XCTestCase {
    private let device = SelectedDevice(id: "fixture-native", name: "Fixture bulb")
    private func configuration(_ revision: UInt64, key: String = "fixture-native-key") -> ProvisionedConfiguration {
        ProvisionedConfiguration(revision: revision, device: device, apiKey: key)
    }
    private func service() -> String { "com.farhanpatel.BulbAssist.tests.\(UUID().uuidString)" }
    private func purge(_ service: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary)
    }

    func testKeychainStoreLoadReplaceDeleteAndRelaunchTombstone() async throws {
        let service = service()
        defer { purge(service) }
        let store = KeychainCredentialStore(service: service)
        let empty = try await store.load()
        XCTAssertNil(empty)
        try await store.store(configuration(1))
        let first = try await store.load()
        XCTAssertEqual(first, configuration(1))
        try await store.store(configuration(1)) // Idempotent retry.
        try await store.store(configuration(2, key: "fixture-native-replacement"))
        let second = try await store.load()
        XCTAssertEqual(second, configuration(2, key: "fixture-native-replacement"))
        try await store.delete(revision: 3)
        try await store.delete(revision: 3)
        let relaunched = KeychainCredentialStore(service: service)
        let removed = try await relaunched.load()
        let revision = try await relaunched.latestRevision()
        XCTAssertNil(removed)
        XCTAssertEqual(revision, 3)
        do {
            try await relaunched.store(configuration(2))
            XCTFail("Stale replay must fail after relaunch")
        } catch { XCTAssertEqual(error as? SetupFailure, .staleRevision) }
        try await relaunched.store(configuration(4))
        let renewed = try await relaunched.load()
        XCTAssertEqual(renewed, configuration(4))
    }

    func testKeychainRejectsConflictingDuplicatesAndSameRevisionRemoval() async throws {
        let service = service()
        defer { purge(service) }
        let store = KeychainCredentialStore(service: service)
        try await store.store(configuration(1))
        do {
            try await store.store(configuration(1, key: "conflicting-fixture-key"))
            XCTFail("Conflicting duplicate must fail")
        } catch { XCTAssertEqual(error as? SetupFailure, .staleRevision) }
        do {
            try await store.delete(revision: 1)
            XCTFail("Removal must use a new revision")
        } catch { XCTAssertEqual(error as? SetupFailure, .staleRevision) }
        let retained = try await store.load()
        XCTAssertEqual(retained, configuration(1))
    }

    func testKeychainUsesDeviceOnlyProtectionAndTombstoneContainsNoKey() async throws {
        let service = service()
        defer { purge(service) }
        let store = KeychainCredentialStore(service: service)
        try await store.store(configuration(1))
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecReturnAttributes as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let attributes = try XCTUnwrap(result as? [String: Any])
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertFalse((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false)
        try await store.delete(revision: 2)
        query[kSecReturnAttributes as String] = nil
        query[kSecReturnData as String] = true
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &result), errSecSuccess)
        let data = try XCTUnwrap(result as? Data)
        let record = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(record.contains("fixture-native-key"))
        XCTAssertFalse(record.contains("apiKey"))
    }

    func testNativeReceiverAcknowledgesDurableWritesAndDeletion() async throws {
        let service = service()
        defer { purge(service) }
        let store = KeychainCredentialStore(service: service)
        let receiver = ProvisioningReceiver(store: store, controllerFactory: { _ in NativeReadController() })
        let saved = await receiver.receive(.provision(configuration(1)))
        XCTAssertEqual(saved.result, .persisted)
        let relaunched = KeychainCredentialStore(service: service)
        let actual = try await relaunched.load()
        XCTAssertEqual(actual, configuration(1))
        let verified = await receiver.receive(.verify(revision: 1))
        if case .connected = verified.result {} else { XCTFail("Requires separate direct read") }
        let removed = await receiver.receive(.remove(revision: 2))
        XCTAssertEqual(removed.result, .removed)
        let tombstone = try await relaunched.latestRevision()
        let deleted = try await relaunched.load()
        XCTAssertEqual(tombstone, 2)
        XCTAssertNil(deleted)
    }

    func testActiveMessageCodecPreservesAllLifecycleCasesAndRejectsForeignPayloads() throws {
        for message in [ProvisioningMessage.provision(configuration(1)), .remove(revision: 2), .verify(revision: 1)] {
            let wire = try ProvisioningWire.encode(message)
            XCTAssertEqual(Set(wire.keys), [ProvisioningWire.payload])
            XCTAssertTrue(wire[ProvisioningWire.payload] is Data)
            XCTAssertEqual(try ProvisioningWire.decode(ProvisioningMessage.self, from: wire), message)
        }
        let persisted = ProvisioningAcknowledgement(revision: 1, result: .persisted)
        XCTAssertEqual(try ProvisioningWire.decode(ProvisioningAcknowledgement.self, from: ProvisioningWire.encode(persisted)), persisted)
        XCTAssertThrowsError(try ProvisioningWire.decode(ProvisioningMessage.self, from: ["unknown": Data()]))
        XCTAssertThrowsError(try ProvisioningWire.decode(ProvisioningMessage.self, from: [ProvisioningWire.payload: Data(), "unexpected": true]))
        XCTAssertThrowsError(try ProvisioningWire.decode(ProvisioningMessage.self, from: [ProvisioningWire.payload: "not-data"]))
    }

    func testReplyWaiterIgnoresDuplicateAndLateReplies() async throws {
        let waiter = MessageReplyWaiter()
        let expected = ProvisioningAcknowledgement(revision: 2, result: .removed)
        let actual: ProvisioningAcknowledgement = try await withCheckedThrowingContinuation { continuation in
            XCTAssertTrue(waiter.install(continuation))
            waiter.finish(.success(expected))
            waiter.finish(.success(ProvisioningAcknowledgement(revision: 1, result: .persisted)))
            waiter.finish(.failure(SetupFailure.interrupted))
        }
        XCTAssertEqual(actual, expected)
    }

    func testCancellationBeforeWaiterInstallationPreventsSending() async {
        let waiter = MessageReplyWaiter()
        waiter.finish(.failure(SetupFailure.interrupted))
        do {
            let _: ProvisioningAcknowledgement = try await withCheckedThrowingContinuation { continuation in
                XCTAssertFalse(waiter.install(continuation))
            }
            XCTFail("Cancelled waiter cannot succeed")
        } catch { XCTAssertEqual(error as? SetupFailure, .interrupted) }
    }
}

private struct NativeReadController: BulbControlling {
    func readState() async throws -> BulbSnapshot { .preview }
    func apply(_ command: BulbCommand) async throws { throw BulbFailure.rejected }
}
