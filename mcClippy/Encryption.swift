//
//  Encryption.swift
//  mcClippy
//

import CryptoKit
import Foundation
import Security

enum EncryptionService {
    private static let keychainService = "mcClippy.encryption"
    private static let keychainAccount = "primaryKey"

    private static let key: SymmetricKey? = {
        if let existing = readKey() { return existing }
        let fresh = SymmetricKey(size: .bits256)
        guard writeKey(fresh) else { return nil }
        return fresh
    }()

    static func seal(_ data: Data) -> Data? {
        guard let key else { return nil }
        guard let sealed = try? ChaChaPoly.seal(data, using: key) else { return nil }
        return sealed.combined
    }

    static func open(_ data: Data) -> Data? {
        guard let key else { return nil }
        guard let box = try? ChaChaPoly.SealedBox(combined: data),
              let opened = try? ChaChaPoly.open(box, using: key) else { return nil }
        return opened
    }

    private static func readKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    @discardableResult
    private static func writeKey(_ key: SymmetricKey) -> Bool {
        let raw = key.withUnsafeBytes { Data($0) }
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: raw,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(attrs as CFDictionary)
        let status = SecItemAdd(attrs as CFDictionary, nil)
        return status == errSecSuccess
    }
}
