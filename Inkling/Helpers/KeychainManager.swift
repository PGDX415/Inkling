import Foundation

/// Centralized API key manager with Keychain storage and UserDefaults migration
@MainActor
final class KeychainManager {
    static let shared = KeychainManager()

    private let userDefaultsKeys = [
        AIProvider.deepseek: "aiApiKey_deepseek",
        AIProvider.siliconflow: "aiApiKey_siliconflow",
        AIProvider.gemini: "aiApiKey_gemini",
    ]

    private static let keychainKeys: [AIProvider: String] = [
        .deepseek: "inkling_api_deepseek",
        .siliconflow: "inkling_api_siliconflow",
        .gemini: "inkling_api_gemini",
    ]

    private let migrationFlagKey = "inkling_keychain_migrated_v1"

    private init() {}

    /// Call once at app launch to migrate legacy UserDefaults keys into Keychain
    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationFlagKey) else { return }

        for (provider, udKey) in userDefaultsKeys {
            let legacyValue = UserDefaults.standard.string(forKey: udKey) ?? ""
            let trimmed = legacyValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                save(key: provider, value: trimmed)
            }
            UserDefaults.standard.removeObject(forKey: udKey)
        }

        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    // MARK: - Public API
    func load(key provider: AIProvider) -> String {
        let chainKey = Self.keychainKeys[provider]!
        return KeychainHelper.load(key: chainKey) ?? ""
    }

    func save(key provider: AIProvider, value: String) {
        let chainKey = Self.keychainKeys[provider]!
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(key: chainKey)
        } else {
            KeychainHelper.save(key: chainKey, value: trimmed)
        }
    }
}
