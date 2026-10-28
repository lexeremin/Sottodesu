import Foundation

/// The places Sottodesu can sort.
enum LocationKind: String, CaseIterable, Identifiable {
    case downloads, desktop, home, custom

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .desktop: return "desktopcomputer"
        case .home: return "house"
        case .custom: return "folder.badge.plus"
        }
    }

    /// The name shown on the card, in the system language.
    var title: String {
        switch self {
        case .downloads: return Localized.string("Downloads")
        case .desktop: return Localized.string("Desktop")
        case .home: return Localized.string("Home")
        case .custom: return Localized.string("Choose Folder…")
        }
    }

    /// One line under the title.
    var summary: String {
        switch self {
        case .downloads: return Localized.string("Everything, sorted by type")
        case .desktop: return Localized.string("Tidy up your desktop")
        case .home: return Localized.string("Loose media and documents only")
        case .custom: return Localized.string("Pick any other folder")
        }
    }
}

/// What Sottodesu may do in a location. The defaults are for Downloads.
struct SortPolicy {
    /// Sort hidden "dot" files (into Config & VPN or Keys & Secrets).
    var includesHiddenFiles = true
    /// Move loose folders into Projects.
    var includesFolders = true
    /// The only categories this location may ever sort.
    var allowedCategories: Set<FileCategory> = Set(FileCategory.allCases)
    /// Send a category to an existing folder instead of making a new one (used for the home folder).
    var redirects: [FileCategory: URL] = [:]

    static let downloads = SortPolicy()

    /// Desktop and other folders: hidden files are left alone.
    static let careful = SortPolicy(includesHiddenFiles: false)

    /// The home folder is full of settings, so it is restricted on purpose: only loose media and documents
    /// (images, videos, audio, documents, books, archives, installers, 3D models, design files) are moved.
    /// Photos, videos, music and documents go to the standard Pictures, Movies, Music and Documents folders;
    /// the rest go into folders inside Documents, so the home folder itself never gets new clutter.
    /// Hidden files, folders (including Projects), apps, code, databases, configuration, keys and secrets,
    /// fonts and your Library are never touched.
    static func home(fileManager: FileManager = .default) -> SortPolicy {
        func folder(_ directory: FileManager.SearchPathDirectory) -> URL? {
            fileManager.urls(for: directory, in: .userDomainMask).first
        }
        var redirects: [FileCategory: URL] = [:]
        redirects[.images] = folder(.picturesDirectory)
        redirects[.videos] = folder(.moviesDirectory)
        redirects[.audio] = folder(.musicDirectory)
        redirects[.documents] = folder(.documentDirectory)

        if let documents = redirects[.documents] {
            for category in [FileCategory.books, .archives, .installers, .models3D, .design] {
                redirects[category] = existingFolder(for: category, in: documents, fileManager: fileManager)
            }
        }
        return SortPolicy(includesHiddenFiles: false, includesFolders: false,
                          allowedCategories: Set(redirects.keys), redirects: redirects)
    }

    /// The category's folder inside `parent` in any supported language if one exists,
    /// otherwise its name in the current language.
    private static func existingFolder(for category: FileCategory, in parent: URL, fileManager: FileManager) -> URL {
        var isDirectory: ObjCBool = false
        for name in category.knownFolderNames {
            let url = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return url
            }
        }
        return parent.appendingPathComponent(category.folderName, isDirectory: true)
    }

    static func policy(for kind: LocationKind) -> SortPolicy {
        switch kind {
        case .downloads: return .downloads
        case .desktop, .custom: return .careful
        case .home: return .home()
        }
    }
}

/// Folders Sottodesu refuses to sort, and a check for folders where sorting could do damage.
enum FolderGuard {
    /// False for system locations, whole disks, the home folder itself (it has its own restricted mode),
    /// your Library, apps, and hidden folders — however the folder was picked.
    static func isAllowedCustomFolder(_ url: URL,
                                      home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let homePath = home.resolvingSymlinksInPath().standardizedFileURL.path
        let components = path.split(separator: "/").map(String.init)
        guard let first = components.first else { return false }          // "/"

        let systemRoots: Set<String> = ["System", "Library", "usr", "bin", "sbin", "private", "Applications",
                                        "opt", "cores", "etc", "var", "dev"]
        if systemRoots.contains(first) { return false }
        if path == "/Users" || path == "/Volumes" { return false }
        if first == "Volumes" && components.count < 3 { return false }     // a whole disk
        if path == homePath { return false }
        if path.hasPrefix(homePath + "/") {
            let relative = path.dropFirst(homePath.count + 1)
            if relative.split(separator: "/").first == "Library" { return false }
        }
        if components.contains(where: { $0.hasPrefix(".") }) { return false }
        if components.contains(where: { $0.lowercased().hasSuffix(".app") }) { return false }
        return true
    }

    /// True if the folder looks like a software project, where moving files around can break things.
    static func looksLikeProject(_ url: URL) -> Bool {
        let markers: Set<String> = [".git", "Package.swift", "package.json", "Cargo.toml", "pyproject.toml",
                                    "requirements.txt", "Makefile", "CMakeLists.txt", "go.mod", "pom.xml",
                                    "build.gradle", "Gemfile", "composer.json"]
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.contains { markers.contains($0) || $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }
}
