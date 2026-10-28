import Foundation

/// Folders Sottodesu sorts things into. Files are matched by extension; loose folders go to `projects`.
///
/// The raw value is a stable English identifier (it is what the history database stores).
/// The folder created on disk is named in the system language; see `folderName`.
enum Category: String, CaseIterable {
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"
    case books = "Books"
    case archives = "Archives"
    case installers = "Installers"
    case models3D = "3D Models"
    case anki = "Anki"
    case config = "Config & VPN"
    case code = "Code"
    case fonts = "Fonts"
    case design = "Design"
    case projects = "Projects"
    case other = "Other"

    var extensions: Set<String> {
        switch self {
        case .images:
            return ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "svg",
                    "arw", "cr2", "cr3", "nef", "dng", "raf", "orf", "rw2"]
        case .videos:
            return ["mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "flv"]
        case .audio:
            return ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff", "opus"]
        case .documents:
            return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key",
                    "txt", "rtf", "md", "csv", "odt", "ods"]
        case .books:
            return ["epub", "mobi", "azw", "azw3", "kfx", "fb2", "djvu", "cbz", "cbr", "ibooks", "lit"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst"]
        case .installers:
            return ["dmg", "pkg", "iso", "ipsw"]
        case .models3D:
            return ["stl", "obj", "fbx", "blend", "3mf", "step", "stp", "gcode", "dae", "glb", "gltf",
                    "usdz", "ply", "f3d", "scad", "3ds"]
        case .anki:
            return ["apkg", "colpkg"]
        case .config:
            return ["ovpn", "conf", "mobileconfig", "json", "yaml", "yml", "toml", "ini", "cfg", "plist",
                    "pem", "crt", "cer", "p12", "pfx"]
        case .code:
            return ["py", "js", "ts", "tsx", "jsx", "swift", "c", "h", "cpp", "hpp", "rs", "go", "java",
                    "rb", "php", "lua", "sh", "ipynb", "sql"]
        case .fonts:
            return ["ttf", "otf", "woff", "woff2", "ttc"]
        case .design:
            return ["psd", "ai", "sketch", "fig", "xd", "indd", "afdesign", "afphoto"]
        case .projects, .other:
            return []
        }
    }

    /// SF Symbol shown next to the category in the history.
    var symbol: String {
        switch self {
        case .images: return "photo"
        case .videos: return "film"
        case .audio: return "music.note"
        case .documents: return "doc.text"
        case .books: return "book.closed"
        case .archives: return "archivebox"
        case .installers: return "shippingbox"
        case .models3D: return "cube"
        case .anki: return "rectangle.stack"
        case .config: return "lock.shield"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .fonts: return "textformat"
        case .design: return "paintpalette"
        case .projects: return "folder"
        case .other: return "tray"
        }
    }

    static func of(extension ext: String) -> Category {
        let lowered = ext.lowercased()
        for category in allCases where category.extensions.contains(lowered) {
            return category
        }
        return .other
    }

    // MARK: Names

    /// The name shown in the interface, in the system language.
    var displayName: String { Localized.string(rawValue) }

    /// The name of the folder Sottodesu creates, in the system language.
    var folderName: String { knownFolderNames[0] }

    /// Every name this category's folder may have had, in any supported language. The current
    /// language comes first. Names are Unicode-normalised so they compare reliably with disk names.
    var knownFolderNames: [String] { Category.variants[self] ?? [Category.normalize(rawValue)] }

    /// Which category a folder name belongs to, in any supported language.
    static func fromFolderName(_ name: String) -> Category? { byFolderName[normalize(name)] }

    static func isCategoryFolderName(_ name: String) -> Bool { fromFolderName(name) != nil }

    static func order(of name: String) -> Int {
        allCases.firstIndex { $0.rawValue == name } ?? Int.max
    }

    static func symbol(for name: String) -> String {
        Category(rawValue: name)?.symbol ?? "tray"
    }

    static func normalize(_ name: String) -> String { name.precomposedStringWithCanonicalMapping }

    private static let variants: [Category: [String]] = {
        var result: [Category: [String]] = [:]
        for category in Category.allCases {
            var names = [category.displayName]
            for bundle in Localized.languageBundles {
                names.append(Localized.string(category.rawValue, in: bundle))
            }
            names.append(category.rawValue)
            var seen = Set<String>()
            result[category] = names.map(normalize).filter { seen.insert($0).inserted }
        }
        return result
    }()

    private static let byFolderName: [String: Category] = {
        var result: [String: Category] = [:]
        for category in Category.allCases {
            for name in category.knownFolderNames where result[name] == nil {
                result[name] = category
            }
        }
        return result
    }()
}

/// A category name with how many items went into it.
struct CategoryCount: Equatable, Hashable {
    /// The category's stable identifier (`Category.rawValue`).
    let name: String
    let count: Int

    /// Orders counts the same way the folders are listed above.
    static func sorted(_ counts: [CategoryCount]) -> [CategoryCount] {
        counts.sorted {
            let (a, b) = (Category.order(of: $0.name), Category.order(of: $1.name))
            return a == b ? $0.name < $1.name : a < b
        }
    }

    /// "Images (5) · Documents (4)", named in the system language.
    static func describe(_ counts: [CategoryCount]) -> String {
        counts.map { "\(Localized.string($0.name)) (\($0.count))" }.joined(separator: " · ")
    }
}

/// One file (or folder) that was moved during a sort, as recorded in the history.
struct MovedFile: Equatable {
    let originalPath: String
    let newPath: String
    let category: String
    let size: Int64
    /// True if this move created the destination folder.
    let createdFolder: Bool
}

struct SortSummary: Equatable {
    var moved = 0
    var skipped = 0
    var byCategory: [String: Int] = [:]

    var categories: [CategoryCount] {
        CategoryCount.sorted(byCategory.map { CategoryCount(name: $0.key, count: $0.value) })
    }
}

enum SorterError: LocalizedError {
    case folderBlockedByFile(String)

    var errorDescription: String? {
        switch self {
        case .folderBlockedByFile(let name):
            return String(localized: "A file named “\(name)” is in the way of the folder Sottodesu needs to create.")
        }
    }
}

/// Sorts what sits directly inside `root`: files go into one subfolder per category, and loose folders
/// go into `Projects`. App bundles and symlinks are left alone.
struct Sorter {
    let root: URL
    /// Items modified more recently than this (in seconds) are left alone, in case they are still downloading.
    var minimumAge: TimeInterval = 5

    static let partialExtensions: Set<String> = ["crdownload", "download", "part", "opdownload", "partial", "tmp"]

    /// Moves items one at a time and calls `onMoved` after each successful move, so the history never
    /// lags behind what actually happened on disk.
    func sort(now: Date = Date(), onMoved: (MovedFile) throws -> Void) throws -> SortSummary {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
                                      .contentModificationDateKey, .fileSizeKey]
        let items = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        var summary = SortSummary()

        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try item.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true { continue }

            let isFolder = values.isDirectory == true
            let category: Category
            if isFolder {
                // Our own folders (in any language) and app bundles stay put; everything else is a loose project.
                if values.isPackage == true || Category.isCategoryFolderName(item.lastPathComponent) { continue }
                category = .projects
            } else if values.isRegularFile == true {
                category = Category.of(extension: item.pathExtension)
            } else {
                continue
            }

            if Sorter.partialExtensions.contains(item.pathExtension.lowercased()) {
                summary.skipped += 1
                continue
            }
            if let modified = values.contentModificationDate, now.timeIntervalSince(modified) < minimumAge {
                summary.skipped += 1
                continue
            }

            let (folder, createdFolder) = try destinationFolder(for: category)
            let destination = Sorter.uniqueDestination(for: item.lastPathComponent, in: folder, isFolder: isFolder)
            do {
                try fm.moveItem(at: item, to: destination)
            } catch {
                if createdFolder { try? fm.removeItem(at: folder) }
                throw error
            }

            try onMoved(MovedFile(
                originalPath: item.path,
                newPath: destination.path,
                category: category.rawValue,
                size: Sorter.size(of: destination, isFolder: isFolder, fileSize: values.fileSize),
                createdFolder: createdFolder
            ))
            summary.moved += 1
            summary.byCategory[category.rawValue, default: 0] += 1
        }
        return summary
    }

    /// Reuses the category's folder if it already exists in any supported language, so changing the
    /// system language never splits your files across "Images" and "Изображения".
    /// Otherwise creates it, named in the current language.
    private func destinationFolder(for category: Category) throws -> (url: URL, created: Bool) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        for name in category.knownFolderNames {
            let url = root.appendingPathComponent(name, isDirectory: true)
            if fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return (url, false)
            }
        }

        let url = root.appendingPathComponent(category.folderName, isDirectory: true)
        if fm.fileExists(atPath: url.path) { throw SorterError.folderBlockedByFile(category.folderName) }
        try fm.createDirectory(at: url, withIntermediateDirectories: false)
        return (url, true)
    }

    /// Size of a file, or the total size of everything inside a folder.
    static func size(of url: URL, isFolder: Bool, fileSize: Int?) -> Int64 {
        if !isFolder { return Int64(fileSize ?? 0) }
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        if let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
            for case let child as URL in walker {
                if let values = try? child.resourceValues(forKeys: keys), values.isRegularFile == true {
                    total += Int64(values.fileSize ?? 0)
                }
            }
        }
        return total
    }

    /// "photo.jpg" -> "photo 2.jpg" -> "photo 3.jpg" until the name is free.
    /// Folders keep their whole name: "v1.2" -> "v1.2 2".
    static func uniqueDestination(for name: String, in folder: URL, isFolder: Bool = false) -> URL {
        let fm = FileManager.default
        let first = folder.appendingPathComponent(name)
        if !fm.fileExists(atPath: first.path) { return first }

        let base = isFolder ? name : (name as NSString).deletingPathExtension
        let ext = isFolder ? "" : (name as NSString).pathExtension
        var n = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
