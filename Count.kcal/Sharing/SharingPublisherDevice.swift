import Foundation
import Security

/// Per-device publisher identity that survives app restarts.
/// A restored backup on another phone receives a new identity.
enum SharingPublisherDevice {

    /// Returns this device-only Keychain identifier, creating it if needed.
    static func identifier() throws -> UUID {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.count.kcal.sharing.publisher",
            kSecAttrAccount as String: "device-identifier",
            kSecAttrSynchronizable as String: false,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8), let id = UUID(uuidString: value) else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode))
            }
            return id
        }
        guard status == errSecItemNotFound else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let id = UUID()
        var attributes = query
        attributes[kSecReturnData as String] = nil
        attributes[kSecMatchLimit as String] = nil
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attributes[kSecValueData as String] = Data(id.uuidString.utf8)
        let added = SecItemAdd(attributes as CFDictionary, nil)
        if added == errSecDuplicateItem {
            // reread the identifier if another caller won the insert
            var concurrentResult: CFTypeRef?
            let read = SecItemCopyMatching(query as CFDictionary, &concurrentResult)
            guard read == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(read)) }
            guard let data = concurrentResult as? Data,
                  let value = String(data: data, encoding: .utf8), let existing = UUID(uuidString: value) else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode))
            }
            return existing
        }
        guard added == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(added)) }
        return id
    }

}
