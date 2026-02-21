import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data
        ]
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            return status == errSecSuccess
        } else {
            var q = query
            q[kSecValueData as String] = data
            let status = SecItemAdd(q as CFDictionary, nil)
            return status == errSecSuccess
        }
    }

    func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }

    func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

