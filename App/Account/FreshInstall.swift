import Foundation
import Security

enum FreshInstall {
    static func clearLeftoverKeychain(
        defaults: UserDefaults = .standard,
        support: URL = .applicationSupportDirectory,
        clear: () -> Void = deleteKeychain
    ) {
        guard !defaults.bool(forKey: FreshInstallConstants.markerKey) else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: support.path)) ?? []
        if contents.isEmpty { clear() }
        defaults.set(true, forKey: FreshInstallConstants.markerKey)
    }

    static func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
