import Foundation
import Security
import BulbCore

/// One atomic, device-local Keychain record holds metadata and credentials or a revision tombstone.
/// No synchronizable items, UserDefaults, logs, or persistent message context are used.
actor KeychainCredentialStore: CredentialStoring {
    private struct Record: Codable {
        let revision: UInt64
        let configuration: ProvisionedConfiguration?
    }
    private let service: String
    private let account: String

    init(service: String = "com.farhanpatel.BulbAssist.configuration", account: String = "selected-bulb") {
        self.service = service
        self.account = account
    }

    func load() throws -> ProvisionedConfiguration? { try read()?.configuration }
    func latestRevision() throws -> UInt64 { try read()?.revision ?? 0 }

    func store(_ configuration: ProvisionedConfiguration) throws {
        let existing = try read()
        if existing?.revision == configuration.revision, existing?.configuration == configuration { return }
        guard configuration.revision > (existing?.revision ?? 0) else { throw SetupFailure.staleRevision }
        try write(Record(revision: configuration.revision, configuration: configuration))
    }

    func delete(revision: UInt64) throws {
        let existing = try read()
        if existing?.revision == revision, existing?.configuration == nil { return }
        guard revision > (existing?.revision ?? 0) else { throw SetupFailure.staleRevision }
        // Update the entire record in place, removing credential bytes while retaining a durable tombstone.
        try write(Record(revision: revision, configuration: nil))
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: false]
    }
    private func read() throws -> Record? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.configuration == nil || record.configuration?.revision == record.revision else {
            throw SetupFailure.persistence
        }
        return record
    }
    private func write(_ record: Record) throws {
        guard let data = try? JSONEncoder().encode(record) else { throw SetupFailure.persistence }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addStatus = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw SetupFailure.persistence }
        } else if status != errSecSuccess {
            throw SetupFailure.persistence
        }
    }
}
