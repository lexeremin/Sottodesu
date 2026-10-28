import Foundation

/// String lookups that can reach every language the app ships, not just the current one.
enum Localized {
    /// `en.lproj`, `ru.lproj`, … inside the app bundle.
    static let languageBundles: [Bundle] = {
        Bundle.main.localizations
            .filter { $0 != "Base" }
            .compactMap { code in
                Bundle.main.path(forResource: code, ofType: "lproj").flatMap { Bundle(path: $0) }
            }
    }()

    /// The string for `key` in the current language. Keys are English, so a missing
    /// translation falls back to readable English.
    static func string(_ key: String, in bundle: Bundle = .main) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
