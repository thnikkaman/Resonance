import Foundation
import Security

/// Stores the user-selected Files folder bookmark in Keychain rather than in
/// the app container. Keychain items normally survive deleting and reinstalling
/// an app with the same bundle identifier, while the bookmark still remains
/// opaque to the app and the user controls the folder in Files.
enum PersistentMusicFolderBookmarkStore {
    private static let service = "com.briangarcia.Resonance.persistent-library"
    private static let account = "music-folder-bookmark"

    static func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    static func save(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        _ = SecItemAdd(item as CFDictionary, nil)
    }
}

/// Stores bytes read from exact same-basename LRC files during the authorized
/// library scan. This is private app cache data, not a copy in the user's
/// MeiKyo music folder, and each scan replaces the cache so removed sidecars
/// do not remain active.
enum PersistentLyricsCompanionDataStore {
    private static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("lyrics-companions.plist")
    }()

    static func load() -> [String: Data] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        return (try? PropertyListDecoder().decode([String: Data].self, from: data)) ?? [:]
    }

    static func save(_ companions: [String: Data]) {
        guard let data = try? PropertyListEncoder().encode(companions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
