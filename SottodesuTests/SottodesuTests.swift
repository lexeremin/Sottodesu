import XCTest
@testable import Sottodesu

final class SottodesuTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var dbDir: URL!
    private var store: HistoryStore!

    override func setUpWithError() throws {
        let id = UUID().uuidString
        root = fm.temporaryDirectory.appendingPathComponent("sottodesu-files-\(id)", isDirectory: true)
        dbDir = fm.temporaryDirectory.appendingPathComponent("sottodesu-db-\(id)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        store = try HistoryStore(databaseURL: dbDir.appendingPathComponent("history.sqlite"))
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
        try? fm.removeItem(at: dbDir)
    }

    // MARK: - Helpers

    private func touch(_ name: String, contents: String = "x") {
        fm.createFile(atPath: root.appendingPathComponent(name).path, contents: Data(contents.utf8))
    }

    private func dir(_ category: Category) -> String { category.folderName }

    private func exists(_ relativePath: String) -> Bool {
        fm.fileExists(atPath: root.appendingPathComponent(relativePath).path)
    }

    @discardableResult
    private func sortAll(minimumAge: TimeInterval = 0) throws -> (summary: SortSummary, runID: Int64) {
        let runID = try store.beginRun()
        let summary = try Sorter(root: root, minimumAge: minimumAge).sort { try self.store.record($0, runID: runID) }
        return (summary, runID)
    }

    // MARK: - Tests

    func testCategoriesByExtension() {
        XCTAssertEqual(Category.of(extension: "JPG"), .images)
        XCTAssertEqual(Category.of(extension: "arw"), .images)
        XCTAssertEqual(Category.of(extension: "mp3"), .audio)
        XCTAssertEqual(Category.of(extension: "pdf"), .documents)
        XCTAssertEqual(Category.of(extension: "md"), .documents)
        XCTAssertEqual(Category.of(extension: "epub"), .books)
        XCTAssertEqual(Category.of(extension: "mobi"), .books)
        XCTAssertEqual(Category.of(extension: "dmg"), .installers)
        XCTAssertEqual(Category.of(extension: "stl"), .models3D)
        XCTAssertEqual(Category.of(extension: "3mf"), .models3D)
        XCTAssertEqual(Category.of(extension: "apkg"), .anki)
        XCTAssertEqual(Category.of(extension: "ovpn"), .config)
        XCTAssertEqual(Category.of(extension: "mobileconfig"), .config)
        XCTAssertEqual(Category.of(extension: "py"), .code)
        XCTAssertEqual(Category.of(extension: "ttf"), .fonts)
        XCTAssertEqual(Category.of(extension: "psd"), .design)
        XCTAssertEqual(Category.of(extension: ""), .other)
        XCTAssertEqual(Category.of(extension: "xyz"), .other)
    }

    func testExtensionsBelongToOnlyOneCategory() {
        var seen: [String: Category] = [:]
        for category in Category.allCases {
            for ext in category.extensions {
                XCTAssertNil(seen[ext], "\(ext) is listed in both \(seen[ext]!.rawValue) and \(category.rawValue)")
                seen[ext] = category
            }
        }
    }

    func testSortsIntoFoldersAndSkipsHiddenAndPartialFiles() throws {
        touch("photo.jpg")
        touch("song.mp3")
        touch("report.pdf")
        touch("novel.epub")
        touch("mystery.xyz")
        touch("noextension")
        touch(".hidden")
        touch("movie.mp4.crdownload")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 6)
        XCTAssertEqual(result.summary.skipped, 1)
        XCTAssertTrue(exists("\(dir(.images))/photo.jpg"))
        XCTAssertTrue(exists("\(dir(.audio))/song.mp3"))
        XCTAssertTrue(exists("\(dir(.documents))/report.pdf"))
        XCTAssertTrue(exists("\(dir(.books))/novel.epub"))
        XCTAssertTrue(exists("\(dir(.other))/mystery.xyz"))
        XCTAssertTrue(exists("\(dir(.other))/noextension"))
        XCTAssertTrue(exists(".hidden"))
        XCTAssertTrue(exists("movie.mp4.crdownload"))
    }

    func testLooseFoldersGoToProjectsAndComeBackOnUndo() throws {
        try fm.createDirectory(at: root.appendingPathComponent("my-project"), withIntermediateDirectories: true)
        touch("my-project/main.py")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 1)
        XCTAssertTrue(exists("\(dir(.projects))/my-project/main.py"))
        XCTAssertFalse(exists("my-project"))

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.restored, 1)
        XCTAssertTrue(exists("my-project/main.py"))
        XCTAssertFalse(exists("\(dir(.projects))"))
    }

    func testAppBundlesAndCategoryFoldersAreLeftAlone() throws {
        try fm.createDirectory(at: root.appendingPathComponent("Thing.app"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("\(dir(.images))"), withIntermediateDirectories: true)
        touch("\(dir(.images))/already.jpg")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 0)
        XCTAssertTrue(exists("Thing.app"))
        XCTAssertTrue(exists("\(dir(.images))/already.jpg"))
        XCTAssertFalse(exists("\(dir(.projects))"))
    }

    func testFolderNameCollisionKeepsWholeName() throws {
        try fm.createDirectory(at: root.appendingPathComponent("\(dir(.projects))/v1.2"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("v1.2"), withIntermediateDirectories: true)

        try sortAll()

        XCTAssertTrue(exists("\(dir(.projects))/v1.2"))
        XCTAssertTrue(exists("\(dir(.projects))/v1.2 2"))
    }

    func testNameCollisionGetsNumberedSuffix() throws {
        try fm.createDirectory(at: root.appendingPathComponent("\(dir(.images))"), withIntermediateDirectories: false)
        touch("\(dir(.images))/photo.jpg", contents: "old")
        touch("photo.jpg", contents: "new")

        try sortAll()

        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("\(dir(.images))/photo.jpg"), encoding: .utf8), "old")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("\(dir(.images))/photo 2.jpg"), encoding: .utf8), "new")
    }

    func testRecentFilesAreSkipped() throws {
        touch("fresh.pdf")

        let result = try sortAll(minimumAge: 3600)

        XCTAssertEqual(result.summary.moved, 0)
        XCTAssertEqual(result.summary.skipped, 1)
        XCTAssertTrue(exists("fresh.pdf"))
    }

    func testRunsAreRecorded() throws {
        touch("a.pdf")
        touch("b.pdf")

        let result = try sortAll()
        let runs = try store.runs()

        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs[0].id, result.runID)
        XCTAssertEqual(runs[0].total, 2)
        XCTAssertEqual(runs[0].reverted, 0)
        XCTAssertEqual(try store.moves(forRun: result.runID).count, 2)
    }

    func testRunRecordsPerCategoryBreakdown() throws {
        touch("a.pdf")
        touch("b.pdf")
        touch("c.jpg")

        let result = try sortAll()

        XCTAssertEqual(try store.runs()[0].categories, [
            CategoryCount(name: "Images", count: 1),
            CategoryCount(name: "Documents", count: 2),
        ])
        XCTAssertEqual(result.summary.categories, try store.runs()[0].categories)
    }

    func testUndoRestoresFilesAndRemovesFoldersItCreated() throws {
        touch("photo.jpg")
        let result = try sortAll()

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.restored, 1)
        XCTAssertTrue(exists("photo.jpg"))
        XCTAssertFalse(exists("\(dir(.images))"))
        XCTAssertTrue(try store.runs()[0].isFullyReverted)
    }

    func testUndoKeepsFoldersThatExistedBefore() throws {
        try fm.createDirectory(at: root.appendingPathComponent("\(dir(.images))"), withIntermediateDirectories: false)
        touch("photo.jpg")
        let result = try sortAll()

        _ = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertTrue(exists("\(dir(.images))"))
        XCTAssertTrue(exists("photo.jpg"))
    }

    func testUndoNeverOverwritesAFileAtTheOriginalPath() throws {
        touch("photo.jpg", contents: "sorted")
        let result = try sortAll()
        touch("photo.jpg", contents: "newer")

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.restored, 0)
        XCTAssertEqual(undo.blocked, 1)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("photo.jpg"), encoding: .utf8), "newer")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("\(dir(.images))/photo.jpg"), encoding: .utf8), "sorted")
    }

    func testUndoReportsFilesThatAreGone() throws {
        touch("photo.jpg")
        let result = try sortAll()
        try fm.removeItem(at: root.appendingPathComponent("\(dir(.images))/photo.jpg"))

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.missing, 1)
        XCTAssertEqual(undo.restored, 0)
    }

    // MARK: - Sizes, scanner and report

    private func write(_ relativePath: String, bytes: Int) throws {
        let url = root.appendingPathComponent(relativePath)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: bytes).write(to: url)
    }

    func testFolderSizesAreRecordedInHistory() throws {
        try write("my-project/data.bin", bytes: 1000)

        let result = try sortAll()

        XCTAssertEqual(try store.moves(forRun: result.runID).first?.size, 1000)
        XCTAssertEqual(try store.runs()[0].bytes, 1000)
    }

    func testScannerGroupsSizesAndFindsLargest() throws {
        try write("\(dir(.images))/a.jpg", bytes: 100)
        try write("\(dir(.documents))/b.pdf", bytes: 300)
        try write("loose/c.bin", bytes: 200)
        try write("d.txt", bytes: 50)

        let result = DownloadsScanner.scan(root: root)

        XCTAssertEqual(result.totalCount, 4)
        XCTAssertEqual(result.totalBytes, 650)
        XCTAssertEqual(result.groups.map(\.name), ["Documents", ScanGroup.loose, "Images", ScanGroup.unsorted])
        XCTAssertEqual(result.largest.first?.name, "b.pdf")
        XCTAssertEqual(result.groups.first?.largest?.name, "b.pdf")
    }

    func testScannerCountsAnAppBundleAsOneItem() throws {
        try write("Thing.app/Contents/MacOS/thing", bytes: 400)
        try write("Thing.app/Contents/Info.plist", bytes: 100)

        let result = DownloadsScanner.scan(root: root)

        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(result.totalBytes, 500)
    }

    func testScannerLimitsTheLargestList() throws {
        for index in 1...5 { try write("f\(index).bin", bytes: index * 10) }

        let result = DownloadsScanner.scan(root: root, limit: 3)

        XCTAssertEqual(result.totalCount, 5)
        XCTAssertEqual(result.largest.map(\.name), ["f5.bin", "f4.bin", "f3.bin"])
    }

    func testReportAggregatesHistory() throws {
        try write("a.pdf", bytes: 10)
        try write("b.pdf", bytes: 20)
        try write("c.jpg", bytes: 30)
        let result = try sortAll()
        let onlyJPG = try store.moves(forRun: result.runID).filter { $0.fileName == "c.jpg" }
        _ = try Reverter.revert(moves: onlyJPG, store: store)

        let report = try store.report()

        XCTAssertEqual(report.sorts, 1)
        XCTAssertEqual(report.items, 3)
        XCTAssertEqual(report.bytes, 60)
        XCTAssertEqual(report.undone, 1)
        XCTAssertEqual(report.categories.first, CategoryStat(name: "Documents", count: 2, bytes: 30))
        XCTAssertNotNil(report.lastSort)
    }

    func testEmptyHistoryGivesAnEmptyReport() throws {
        XCTAssertEqual(try store.report(), HistoryReport())
    }

    // MARK: - Languages

    func testEveryCategoryIsNamedInEveryLanguage() {
        let codes = Set(Bundle.main.localizations)
        XCTAssertTrue(codes.isSuperset(of: ["en", "ru", "zh-Hans", "ko", "ja", "fr"]), "Missing languages: \(codes)")
        XCTAssertGreaterThanOrEqual(Localized.languageBundles.count, 5)

        for bundle in Localized.languageBundles {
            let names = Category.allCases.map { Localized.string($0.rawValue, in: bundle) }
            XCTAssertEqual(Set(names).count, names.count, "Two categories share a folder name in \(bundle.bundlePath)")
            XCTAssertFalse(names.contains { $0.isEmpty || $0.contains("/") || $0.contains(":") })
        }
    }

    func testExistingFolderInAnotherLanguageIsReused() throws {
        guard let other = Category.images.knownFolderNames.first(where: { $0 != Category.images.folderName }) else {
            throw XCTSkip("Only one spelling of the Images folder is available")
        }
        try fm.createDirectory(at: root.appendingPathComponent(other), withIntermediateDirectories: true)
        touch("photo.jpg")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 1)
        XCTAssertTrue(exists("\(other)/photo.jpg"))
        XCTAssertFalse(exists(dir(.images)), "A second Images folder was created")
    }

    func testCategoryFoldersInAnyLanguageAreLeftAlone() throws {
        let spellings = Category.documents.knownFolderNames
        for name in spellings {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 0)
        XCTAssertFalse(exists(dir(.projects)))
    }

    func testFolderNamesResolveBackToCategories() {
        for category in Category.allCases {
            for name in category.knownFolderNames {
                XCTAssertEqual(Category.fromFolderName(name), category, "\(name)")
            }
        }
        XCTAssertNil(Category.fromFolderName("my-project"))
    }

    func testBreakdownUsesDisplayNames() {
        let text = CategoryCount.describe([CategoryCount(name: "Images", count: 2), CategoryCount(name: "Code", count: 1)])
        XCTAssertEqual(text, "\(Category.images.displayName) (2) · \(Category.code.displayName) (1)")
    }
}
