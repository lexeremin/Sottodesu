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
        XCTAssertEqual(Category.of(extension: "dmg"), .installers)
        XCTAssertEqual(Category.of(extension: ""), .other)
        XCTAssertEqual(Category.of(extension: "xyz"), .other)
    }

    func testSortsIntoFoldersAndSkipsHiddenPartialAndDirectories() throws {
        touch("photo.jpg")
        touch("song.mp3")
        touch("report.pdf")
        touch("mystery.xyz")
        touch("noextension")
        touch(".hidden")
        touch("movie.mp4.crdownload")
        try fm.createDirectory(at: root.appendingPathComponent("Some Folder"), withIntermediateDirectories: false)

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 5)
        XCTAssertEqual(result.summary.skipped, 1)
        XCTAssertTrue(exists("Images/photo.jpg"))
        XCTAssertTrue(exists("Audio/song.mp3"))
        XCTAssertTrue(exists("Documents/report.pdf"))
        XCTAssertTrue(exists("Other/mystery.xyz"))
        XCTAssertTrue(exists("Other/noextension"))
        XCTAssertTrue(exists(".hidden"))
        XCTAssertTrue(exists("movie.mp4.crdownload"))
        XCTAssertTrue(exists("Some Folder"))
    }

    func testNameCollisionGetsNumberedSuffix() throws {
        try fm.createDirectory(at: root.appendingPathComponent("Images"), withIntermediateDirectories: false)
        touch("Images/photo.jpg", contents: "old")
        touch("photo.jpg", contents: "new")

        try sortAll()

        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Images/photo.jpg"), encoding: .utf8), "old")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Images/photo 2.jpg"), encoding: .utf8), "new")
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

    func testUndoRestoresFilesAndRemovesFoldersItCreated() throws {
        touch("photo.jpg")
        let result = try sortAll()

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.restored, 1)
        XCTAssertTrue(exists("photo.jpg"))
        XCTAssertFalse(exists("Images"))
        XCTAssertTrue(try store.runs()[0].isFullyReverted)
    }

    func testUndoKeepsFoldersThatExistedBefore() throws {
        try fm.createDirectory(at: root.appendingPathComponent("Images"), withIntermediateDirectories: false)
        touch("photo.jpg")
        let result = try sortAll()

        _ = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertTrue(exists("Images"))
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
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("Images/photo.jpg"), encoding: .utf8), "sorted")
    }

    func testUndoReportsFilesThatAreGone() throws {
        touch("photo.jpg")
        let result = try sortAll()
        try fm.removeItem(at: root.appendingPathComponent("Images/photo.jpg"))

        let undo = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)

        XCTAssertEqual(undo.missing, 1)
        XCTAssertEqual(undo.restored, 0)
    }
}
