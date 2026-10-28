import Foundation

/// Folders Sottodesu sorts files into, chosen by file extension.
enum Category: String, CaseIterable {
    case images = "Images"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"
    case archives = "Archives"
    case installers = "Installers"
    case other = "Other"

    var extensions: Set<String> {
        switch self {
        case .images:
            return ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tif", "tiff", "bmp", "svg", "psd",
                    "arw", "cr2", "cr3", "nef", "dng", "raf", "orf", "rw2"]
        case .videos:
            return ["mp4", "mov", "mkv", "avi", "m4v", "webm", "wmv", "flv"]
        case .audio:
            return ["mp3", "m4a", "wav", "flac", "aac", "ogg", "aiff", "opus"]
        case .documents:
            return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pages", "numbers", "key",
                    "txt", "rtf", "md", "csv", "epub", "odt", "ods"]
        case .archives:
            return ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]
        case .installers:
            return ["dmg", "pkg", "iso", "ipsw"]
        case .other:
            return []
        }
    }

    static func of(extension ext: String) -> Category {
        let lowered = ext.lowercased()
        for category in allCases where category.extensions.contains(lowered) {
            return category
        }
        return .other
    }
}

/// One file that was moved during a sort, as recorded in the history.
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
}

enum SorterError: LocalizedError {
    case folderBlockedByFile(String)

    var errorDescription: String? {
        switch self {
        case .folderBlockedByFile(let name):
            return "A file named “\(name)” is in the way of the folder Sottodesu needs to create."
        }
    }
}

/// Sorts the regular files directly inside `root` into one subfolder per category.
struct Sorter {
    let root: URL
    /// Files modified more recently than this (in seconds) are left alone, in case they are still downloading.
    var minimumAge: TimeInterval = 5

    static let partialExtensions: Set<String> = ["crdownload", "download", "part", "opdownload", "partial", "tmp"]

    /// Moves files one at a time and calls `onMoved` after each successful move, so the history never
    /// lags behind what actually happened on disk.
    func sort(now: Date = Date(), onMoved: (MovedFile) throws -> Void) throws -> SortSummary {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]
        let items = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        var summary = SortSummary()

        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try item.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }

            let ext = item.pathExtension.lowercased()
            if Sorter.partialExtensions.contains(ext) {
                summary.skipped += 1
                continue
            }
            if let modified = values.contentModificationDate, now.timeIntervalSince(modified) < minimumAge {
                summary.skipped += 1
                continue
            }

            let category = Category.of(extension: ext)
            let folder = root.appendingPathComponent(category.rawValue, isDirectory: true)

            var isDirectory: ObjCBool = false
            var createdFolder = false
            if fm.fileExists(atPath: folder.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue { throw SorterError.folderBlockedByFile(category.rawValue) }
            } else {
                try fm.createDirectory(at: folder, withIntermediateDirectories: false)
                createdFolder = true
            }

            let destination = Sorter.uniqueDestination(for: item.lastPathComponent, in: folder)
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
                size: Int64(values.fileSize ?? 0),
                createdFolder: createdFolder
            ))
            summary.moved += 1
        }
        return summary
    }

    /// "photo.jpg" -> "photo 2.jpg" -> "photo 3.jpg" until the name is free.
    static func uniqueDestination(for name: String, in folder: URL) -> URL {
        let fm = FileManager.default
        let first = folder.appendingPathComponent(name)
        if !fm.fileExists(atPath: first.path) { return first }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
