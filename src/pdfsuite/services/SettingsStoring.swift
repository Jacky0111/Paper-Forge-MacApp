import Foundation

protocol SettingsStoring {
    func value(forKey key: String) -> String?
    func setValue(_ value: String?, forKey key: String)
}

struct UserDefaultsSettingsStore: SettingsStoring {
    private let defaults = UserDefaults.standard

    func value(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setValue(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
