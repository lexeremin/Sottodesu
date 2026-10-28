import Foundation

/// Group identifiers for what is found in Downloads. A category folder's group is the category's
/// stable identifier (`FileCategory.rawValue`); these two are the rest. All of them are also string
/// catalog keys, so `Localized.string(id)` gives the name to show.
enum ScanGroup {
    /// Files sitting directly in Downloads.
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
        let keys: [URLResourceKey] = [.isRegularFileKey, .isPackageKey, .isSymbolicLinkKey,
                                      .fileSizeKey, .contentModificationDateKey]
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                         options: [.skipsHiddenFiles], errorHandler: { _, _ in true }) else {
            return ScanResult()
        }

        let rootDepth = root.pathComponents.count
        var items: [ScannedItem] = []
        var stats: [String: GroupStat] = [:]
        var total: Int64 = 0

        for case let url as URL in walker {
            if Task.isCancelled { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                walker.skipDescendants()
                continue
            }

            let size: Int64
            if values.isPackage == true {
                size = packageSize(url)
                walker.skipDescendants()
            } else if values.isRegularFile == true {
                size = Int64(values.fileSize ?? 0)
            } else {
                continue
            }

            let item = ScannedItem(url: url, size: size,
                                   modifiedDate: values.contentModificationDate ?? .distantPast,
                                   group: group(for: url, rootDepth: rootDepth))
            items.append(item)
            total += size

            var stat = stats[item.group, default: GroupStat(name: item.group)]
            stat.count += 1
            stat.bytes += size
            if stat.largest == nil || size > stat.largest!.size { stat.largest = item }
            stats[item.group] = stat
        }

        items.sort { $0.size > $1.size }
        return ScanResult(
            totalBytes: total,
            totalCount: items.count,
            groups: stats.values.sorted { $0.bytes > $1.bytes },
            largest: Array(items.prefix(limit)),
            scannedAt: Date()
        )
    }

    private static func group(for url: URL, rootDepth: Int) -> String {
        let parts = url.pathComponents
        if parts.count <= rootDepth + 1 { return ScanGroup.unsorted }
        return FileCategory.fromFolderName(parts[rootDepth])?.rawValue ?? ScanGroup.loose
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
