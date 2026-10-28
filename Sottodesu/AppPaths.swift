import Foundation

/// Every place Sottodesu reads from or writes to. Keeping this list short is what keeps the footprint small.
enum AppPaths {
    static var downloads: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    static var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    private static var library: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    }

    static var bundleID: String { Bundle.main.bundleIdentifier ?? "dev.sottodesu.app" }

    /// The only thing the app creates on purpose: one small SQLite file.
    static var supportDirectory: URL {
        library.appendingPathComponent("Application Support/Sottodesu", isDirectory: true)
    }

    static var database: URL { supportDirectory.appendingPathComponent("history.sqlite") }

    /// Places macOS itself may create for an app. The uninstall command clears these too.
    static var systemGeneratedLeftovers: [URL] {
        [
            library.appendingPathComponent("Preferences/\(bundleID).plist"),
            library.appendingPathComponent("Saved Application State/\(bundleID).savedState"),
            library.appendingPathComponent("Caches/\(bundleID)"),
            library.appendingPathComponent("HTTPStorages/\(bundleID)"),
        ]
    }
}
