import Foundation

/// Group identifiers for what is found in a folder. A category folder's group is the category's
/// stable identifier (`FileCategory.rawValue`); these two are the rest. All of them are also string
/// catalog keys, so `Localized.string(id)` gives the name to show.
enum ScanGroup {
    /// Files sitting directly in the folder.
    static let unsorted = "Not sorted yet"
    /// Anything inside a folder that isn't one of Sottodesu's category folders.
    static let loose = "Loose folders"
}

struct ScannedItem: Identifiable, Hashable, Sendable {
    let url: URL
    let size: Int64
    let modifiedDate: Date
    let group: String

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var folderPath: String {
        (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }
}

struct GroupStat: Identifiable, Equatable, Sendable {
    let name: String
    var count = 0
    var bytes: Int64 = 0
    var largest: ScannedItem?
    var id: String { name }
}

struct ScanResult: Equatable, Sendable {
    var totalBytes: Int64 = 0
    var totalCount = 0
    /// One entry per group, biggest first.
    var groups: [GroupStat] = []
    /// The biggest items overall, biggest first.
    var largest: [ScannedItem] = []
    var scannedAt = Date()
}

/// Measures everything inside a folder. App bundles count as one item rather than thousands of files.
enum DownloadsScanner {
    static func scan(root: URL, limit: Int = 500) -> ScanResult {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
                                      .fileSizeKey, .contentModificationDateKey]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                         options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else {
            return ScanResult()
        }

        var kept: [ScannedItem] = []
        var stats: [String: GroupStat] = [:]
        var total: Int64 = 0
        var count = 0
        // The group of the top-level folder being walked. The enumerator goes depth-first, so this stays
        // right until the next top-level entry. (Using the enumerator's own depth avoids comparing paths,
        // which can differ between /var and /private/var.)
        var folderGroup = ScanGroup.loose

        for case let url as URL in walker {
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                walker.skipDescendants()
                continue
            }

            let isPackage = values.isPackage == true
            if values.isDirectory == true && !isPackage {
                if walker.level == 1 {
                    folderGroup = FileCategory.fromFolderName(url.lastPathComponent)?.rawValue ?? ScanGroup.loose
                }
                continue
            }

            let size: Int64
            if isPackage {
                size = packageSize(url)
                walker.skipDescendants()
            } else if values.isRegularFile == true {
                size = Int64(values.fileSize ?? 0)
            } else {
                continue
            }

            let item = ScannedItem(url: url, size: size,
                                   modifiedDate: values.contentModificationDate ?? .distantPast,
                                   group: walker.level == 1 ? ScanGroup.unsorted : folderGroup)
            total += size
            count += 1

            var stat = stats[item.group, default: GroupStat(name: item.group)]
            stat.count += 1
            stat.bytes += size
            if stat.largest == nil || size > stat.largest!.size { stat.largest = item }
            stats[item.group] = stat

            // Keep memory bounded on huge folders: only the biggest few items are ever needed.
            kept.append(item)
            if kept.count > limit * 4 {
                kept.sort { $0.size > $1.size }
                kept.removeLast(kept.count - limit)
            }
        }

        kept.sort { $0.size > $1.size }
        return ScanResult(
            totalBytes: total,
            totalCount: count,
            groups: stats.values.sorted { $0.bytes > $1.bytes },
            largest: Array(kept.prefix(limit)),
            scannedAt: Date()
        )
    }

    private static func packageSize(_ url: URL) -> Int64 {
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
}
