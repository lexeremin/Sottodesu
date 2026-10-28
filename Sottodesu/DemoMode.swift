import Foundation

/// A made-up history and Downloads folder, used to take screenshots.
///
/// Start the app with `--demo` (and optionally `--tab sort|report|largest`). Nothing real is read or
/// written: the history lives in a temporary folder and all sizes are invented.
enum DemoMode {
    static var isActive: Bool { CommandLine.arguments.contains("--demo") }

    private static var requestedTab: AppTab {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--tab"), args.indices.contains(index + 1) else { return .sort }
        return AppTab(rawValue: args[index + 1]) ?? .sort
    }

    @MainActor
    static func makeModel() -> AppModel? {
        do {
            let base = FileManager.default.temporaryDirectory
                .appendingPathComponent("sottodesu-demo-\(UUID().uuidString)", isDirectory: true)
            let downloads = base.appendingPathComponent("Downloads", isDirectory: true)
            try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

            let store = try HistoryStore(databaseURL: base.appendingPathComponent("history.sqlite"))
            let latest = try seedHistory(store)

            var status = String(localized: "Ready to sort.")
            if let newest = try store.runs().first {
                status = String(localized: "Sorted \(newest.total) items:") + " " + CategoryCount.describe(newest.categories)
            }

            let model = AppModel(demoStore: store, downloads: downloads, scan: sampleScan(),
                                 status: status, lastSortRunID: latest)
            model.tab = requestedTab
            return model
        } catch {
            return nil
        }
    }

    // MARK: - History

    private struct Item {
        let category: FileCategory
        let name: String
        let megabytes: Double
    }

    private static func item(_ category: FileCategory, _ name: String, _ megabytes: Double) -> Item {
        Item(category: category, name: name, megabytes: megabytes)
    }

    /// Five sorts, oldest first so the newest ends up on top. The oldest has been undone.
    private static func seedHistory(_ store: HistoryStore) throws -> Int64 {
        let downloads = AppPaths.downloads
        let desktop = AppPaths.desktop
        let inbox = AppPaths.home.appendingPathComponent("Work Inbox", isDirectory: true)

        let today: [Item] = [
            item(.images, "IMG_4821.heic", 3.4), item(.images, "Screenshot 2026-10-27 at 14.02.11.png", 1.1),
            item(.images, "wallpaper-4k.jpg", 5.8), item(.images, "DSC00231.arw", 24),
            item(.images, "logo-final.svg", 0.02), item(.images, "cover-art.png", 2.3),
            item(.documents, "Invoice-October.pdf", 0.3), item(.documents, "Lease-agreement.docx", 0.2),
            item(.documents, "Budget-2026.xlsx", 0.8), item(.documents, "Flight-ticket.pdf", 0.1),
            item(.documents, "Notes.md", 0.01),
            item(.installers, "Firefox 142.0.dmg", 118), item(.installers, "Blender-4.5-macOS.dmg", 380),
            item(.archives, "project-assets.zip", 212), item(.archives, "dataset.tar.gz", 640),
            item(.books, "Designing-Data-Intensive-Applications.epub", 4.2), item(.books, "Dune.mobi", 1.4),
            item(.models3D, "benchy.stl", 11), item(.models3D, "bracket-v3.3mf", 3.2),
            item(.config, "client.ovpn", 0.004), item(.config, ".gitignore", 0.0003),
            item(.secrets, ".env.production", 0.0002),
            item(.projects, "my-website", 48),
            item(.other, "backup-2025.bin", 52),
        ]
        let yesterday: [Item] = [
            item(.videos, "Screen Recording 2026-10-26.mov", 842), item(.videos, "trailer.mp4", 310),
            item(.videos, "Lecture-07-Distributed-Systems.mkv", 1480),
            item(.audio, "podcast-ep-112.mp3", 62), item(.audio, "ambient-mix.flac", 148),
            item(.audio, "voice-memo.m4a", 4.1),
            item(.documents, "Thesis-draft-v4.pdf", 5.6), item(.documents, "Resume-2026.pdf", 0.2),
            item(.fonts, "Inter.ttf", 0.8),
        ]
        let threeDaysAgo: [Item] = [
            item(.code, "main.py", 0.004), item(.code, "data-export.ipynb", 9), item(.databases, "schema.sql", 0.1),
            item(.design, "Photoshop-Mockups.psd", 240), item(.design, "brand-guidelines.sketch", 18),
            item(.design, "icons.fig", 6),
            item(.images, "Panorama-Alps.heic", 71), item(.images, "team-photo.jpg", 4.6),
            item(.images, "diagram.png", 0.4),
            item(.databases, "Japanese-Core-2k.apkg", 38),
            item(.fonts, "JetBrainsMono.ttf", 0.3),
            item(.documents, "Quarterly-Report.pdf", 2.4),
        ]
        let lastWeek: [Item] = [
            item(.installers, "ubuntu-26.04-desktop-amd64.iso", 5320), item(.installers, "Zoom.pkg", 98),
            item(.archives, "Final-Cut-Project-Backup.zip", 2260), item(.archives, "photos-2024.7z", 940),
            item(.books, "Art-of-Computer-Programming.djvu", 86),
            item(.projects, "react-dashboard", 310),
            item(.other, "old-database.dump", 128),
        ]
        let undone: [Item] = [
            item(.documents, "Scanned-Archive-2019.pdf", 128), item(.documents, "Contract-draft.docx", 0.4),
            item(.documents, "Receipts.csv", 0.1),
            item(.images, "IMG_0042.dng", 96), item(.images, "scan-001.tif", 22),
        ]

        let sorts: [(hoursAgo: Double, wasUndone: Bool, location: URL, items: [Item])] = [
            (21 * 24, true, inbox, undone),
            (8 * 24, false, downloads, lastWeek),
            (3 * 24 + 5, false, desktop, threeDaysAgo),
            (18, false, downloads, yesterday),
            (2, false, downloads, today),
        ]

        var latest: Int64 = 0
        for sort in sorts {
            let runID = try store.beginRun(at: Date().addingTimeInterval(-sort.hoursAgo * 3600), location: sort.location.path)
            for entry in sort.items {
                let folder = sort.location.appendingPathComponent(entry.category.folderName, isDirectory: true)
                try store.record(MovedFile(
                    originalPath: sort.location.appendingPathComponent(entry.name).path,
                    newPath: folder.appendingPathComponent(entry.name).path,
                    category: entry.category.rawValue,
                    size: Int64(entry.megabytes * 1_000_000),
                    createdFolder: false
                ), runID: runID)
            }
            if sort.wasUndone {
                for move in try store.moves(forRun: runID) { try store.markReverted(moveID: move.id) }
            }
            latest = runID
        }
        return latest
    }

    // MARK: - Disk space

    private static func sampleScan() -> ScanResult {
        let downloads = AppPaths.downloads

        func file(_ group: String, _ path: String, _ megabytes: Double, daysAgo: Double) -> ScannedItem {
            let folder = FileCategory(rawValue: group)?.folderName
            let base = folder.map { downloads.appendingPathComponent($0, isDirectory: true) } ?? downloads
            return ScannedItem(
                url: base.appendingPathComponent(path),
                size: Int64(megabytes * 1_000_000),
                modifiedDate: Date().addingTimeInterval(-daysAgo * 86_400),
                group: group
            )
        }

        let videos = FileCategory.videos.rawValue
        let installers = FileCategory.installers.rawValue
        let archives = FileCategory.archives.rawValue
        let projects = FileCategory.projects.rawValue
        let design = FileCategory.design.rawValue
        let documents = FileCategory.documents.rawValue
        let audio = FileCategory.audio.rawValue
        let images = FileCategory.images.rawValue
        let models = FileCategory.models3D.rawValue
        let books = FileCategory.books.rawValue
        let databases = FileCategory.databases.rawValue
        let other = FileCategory.other.rawValue
        let code = FileCategory.code.rawValue

        let items: [ScannedItem] = [
            file(videos, "wedding-4k-raw.mov", 4100, daysAgo: 12),
            file(videos, "Lecture-07-Distributed-Systems.mkv", 1480, daysAgo: 3),
            file(videos, "Screen Recording 2026-10-26.mov", 842, daysAgo: 2),
            file(installers, "ubuntu-26.04-desktop-amd64.iso", 5320, daysAgo: 20),
            file(installers, "Blender-4.5-macOS.dmg", 380, daysAgo: 8),
            file(archives, "dataset-imagenet-subset.tar.gz", 3100, daysAgo: 15),
            file(archives, "Final-Cut-Project-Backup.zip", 2260, daysAgo: 40),
            file(archives, "project-assets.zip", 212, daysAgo: 1),
            file(projects, "my-website/media/hero-loop.mp4", 310, daysAgo: 6),
            file(projects, "react-dashboard/build/static/js/main.js.map", 48, daysAgo: 9),
            file(design, "Photoshop-Mockups.psd", 240, daysAgo: 21),
            file(design, "brand-guidelines.sketch", 18, daysAgo: 5),
            file(documents, "Scanned-Archive-2019.pdf", 128, daysAgo: 60),
            file(documents, "Thesis-draft-v4.pdf", 5.6, daysAgo: 1),
            file(audio, "ambient-mix.flac", 148, daysAgo: 4),
            file(audio, "podcast-ep-112.mp3", 62, daysAgo: 1),
            file(images, "Panorama-Alps.heic", 71, daysAgo: 30),
            file(images, "DSC00231.arw", 24, daysAgo: 0.2),
            file(models, "voron-v2-assembly.step", 210, daysAgo: 50),
            file(models, "benchy.stl", 11, daysAgo: 0.1),
            file(books, "Art-of-Computer-Programming.djvu", 86, daysAgo: 90),
            file(books, "Dune.mobi", 1.4, daysAgo: 0.3),
            file(databases, "Japanese-Core-2k.apkg", 38, daysAgo: 2),
            file(code, "data-export.ipynb", 9, daysAgo: 4),
            file(other, "backup-2025.bin", 52, daysAgo: 70),
            file(ScanGroup.unsorted, "Zoom.pkg", 98, daysAgo: 0.01),
            file(ScanGroup.unsorted, "Keynote-Template.key", 14, daysAgo: 0.01),
            file(ScanGroup.loose, "old-site-backup/uploads.tar", 230, daysAgo: 120),
        ]
        let largest = items.sorted { $0.size > $1.size }

        let table: [(id: String, count: Int, megabytes: Double)] = [
            (videos, 214, 18_600), (installers, 61, 9_400), (archives, 87, 7_200), (projects, 1_520, 3_400),
            (images, 2_210, 2_300), (audio, 168, 1_900), (design, 74, 1_300), (documents, 412, 1_200),
            (models, 96, 980), (books, 134, 640), (ScanGroup.loose, 940, 480), (other, 77, 280),
            (databases, 12, 160), (ScanGroup.unsorted, 3, 112), (FileCategory.fonts.rawValue, 31, 24),
            (code, 205, 12), (FileCategory.config.rawValue, 18, 2), (FileCategory.secrets.rawValue, 3, 1),
        ]
        let groups = table
            .map { entry in
                GroupStat(name: entry.id, count: entry.count, bytes: Int64(entry.megabytes * 1_000_000),
                          largest: largest.first { $0.group == entry.id })
            }
            .sorted { $0.bytes > $1.bytes }

        return ScanResult(
            totalBytes: groups.reduce(Int64(0)) { $0 + $1.bytes },
            totalCount: groups.reduce(0) { $0 + $1.count },
            groups: groups,
            largest: largest,
            scannedAt: Date()
        )
    }
}
