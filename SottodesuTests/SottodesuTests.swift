import XCTest
@testable import Sottodesu

final class SottodesuTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var dbDir: URL!
    private var store: HistoryStore!
    /// What the home folder is allowed to sort.
    private let homeCategories: Set<FileCategory> = [
        .images, .videos, .audio, .documents, .books, .archives, .installers, .models3D, .design,
    ]

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

    private func dir(_ category: FileCategory) -> String { category.folderName }

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
        XCTAssertEqual(FileCategory.of(extension: "JPG"), .images)
        XCTAssertEqual(FileCategory.of(extension: "arw"), .images)
        XCTAssertEqual(FileCategory.of(extension: "mp3"), .audio)
        XCTAssertEqual(FileCategory.of(extension: "pdf"), .documents)
        XCTAssertEqual(FileCategory.of(extension: "md"), .documents)
        XCTAssertEqual(FileCategory.of(extension: "epub"), .books)
        XCTAssertEqual(FileCategory.of(extension: "mobi"), .books)
        XCTAssertEqual(FileCategory.of(extension: "dmg"), .installers)
        XCTAssertEqual(FileCategory.of(extension: "stl"), .models3D)
        XCTAssertEqual(FileCategory.of(extension: "3mf"), .models3D)
        XCTAssertEqual(FileCategory.of(extension: "apkg"), .databases)
        XCTAssertEqual(FileCategory.of(extension: "sqlite"), .databases)
        XCTAssertEqual(FileCategory.of(extension: "sql"), .databases)
        XCTAssertEqual(FileCategory.of(extension: "ovpn"), .config)
        XCTAssertEqual(FileCategory.of(extension: "pem"), .secrets)
        XCTAssertEqual(FileCategory.of(extension: "cert"), .secrets)
        XCTAssertEqual(FileCategory.of(extension: "env"), .secrets)
        XCTAssertEqual(FileCategory.of(extension: "mobileconfig"), .config)
        XCTAssertEqual(FileCategory.of(extension: "py"), .code)
        XCTAssertEqual(FileCategory.of(extension: "ttf"), .fonts)
        XCTAssertEqual(FileCategory.of(extension: "psd"), .design)
        XCTAssertEqual(FileCategory.of(extension: ""), .other)
        XCTAssertEqual(FileCategory.of(extension: "xyz"), .other)
    }

    func testExtensionsBelongToOnlyOneCategory() {
        var seen: [String: FileCategory] = [:]
        for category in FileCategory.allCases {
            for ext in category.extensions {
                XCTAssertNil(seen[ext], "\(ext) is listed in both \(seen[ext]!.rawValue) and \(category.rawValue)")
                seen[ext] = category
            }
        }
    }

    func testSortsIntoFoldersAndSkipsSystemHiddenAndPartialFiles() throws {
        touch("photo.jpg")
        touch("song.mp3")
        touch("report.pdf")
        touch("novel.epub")
        touch("mystery.xyz")
        touch("noextension")
        touch(".hidden")
        touch(".DS_Store")
        touch("movie.mp4.crdownload")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 7)
        XCTAssertEqual(result.summary.skipped, 1)
        XCTAssertTrue(exists("\(dir(.images))/photo.jpg"))
        XCTAssertTrue(exists("\(dir(.audio))/song.mp3"))
        XCTAssertTrue(exists("\(dir(.documents))/report.pdf"))
        XCTAssertTrue(exists("\(dir(.books))/novel.epub"))
        XCTAssertTrue(exists("\(dir(.other))/mystery.xyz"))
        XCTAssertTrue(exists("\(dir(.other))/noextension"))
        XCTAssertTrue(exists("\(dir(.config))/.hidden"))
        XCTAssertTrue(exists(".DS_Store"))
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
            let names = FileCategory.allCases.map { Localized.string($0.rawValue, in: bundle) }
            XCTAssertEqual(Set(names).count, names.count, "Two categories share a folder name in \(bundle.bundlePath)")
            XCTAssertFalse(names.contains { $0.isEmpty || $0.contains("/") || $0.contains(":") })
        }
    }

    func testExistingFolderInAnotherLanguageIsReused() throws {
        guard let other = FileCategory.images.knownFolderNames.first(where: { $0 != FileCategory.images.folderName }) else {
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
        let spellings = FileCategory.documents.knownFolderNames
        for name in spellings {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 0)
        XCTAssertFalse(exists(dir(.projects)))
    }

    func testFolderNamesResolveBackToCategories() {
        for category in FileCategory.allCases {
            for name in category.knownFolderNames {
                XCTAssertEqual(FileCategory.fromFolderName(name), category, "\(name)")
            }
        }
        XCTAssertNil(FileCategory.fromFolderName("my-project"))
    }

    func testBreakdownUsesDisplayNames() {
        let text = CategoryCount.describe([CategoryCount(name: "Images", count: 2), CategoryCount(name: "Code", count: 1)])
        XCTAssertEqual(text, "\(FileCategory.images.displayName) (2) · \(FileCategory.code.displayName) (1)")
    }

    // MARK: - Hidden files and secrets

    func testClassifiesByWholeFileName() {
        XCTAssertEqual(FileCategory.of(fileName: ".gitignore"), .config)
        XCTAssertEqual(FileCategory.of(fileName: ".zshrc"), .config)
        XCTAssertEqual(FileCategory.of(fileName: ".env"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: ".env.local"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: ".env.example"), .config)
        XCTAssertEqual(FileCategory.of(fileName: ".cert"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: ".npmrc"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: "server.cert"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: "production.env"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: "id_ed25519"), .secrets)
        XCTAssertEqual(FileCategory.of(fileName: "id_ed25519.pub"), .other)
        XCTAssertEqual(FileCategory.of(fileName: "vpn.ovpn"), .config)
        XCTAssertEqual(FileCategory.of(fileName: "Photo.JPG"), .images)
    }

    func testDotfilesGoToConfigAndSecretsToTheirOwnPrivateFolder() throws {
        touch(".gitignore")
        touch(".env")
        touch(".env.production")
        touch("server.cert")
        touch("ca.pem")
        touch("vpn.ovpn")
        try fm.createDirectory(at: root.appendingPathComponent(".ssh"), withIntermediateDirectories: true)
        touch(".DS_Store")
        touch(".localized")
        touch("._photo.jpg")
        touch(".com.google.Chrome.abc123")

        let result = try sortAll()

        XCTAssertEqual(result.summary.moved, 6)
        XCTAssertTrue(exists("\(dir(.config))/.gitignore"))
        XCTAssertTrue(exists("\(dir(.config))/vpn.ovpn"))
        for name in [".env", ".env.production", "server.cert", "ca.pem"] {
            XCTAssertTrue(exists("\(dir(.secrets))/\(name)"), name)
        }
        for name in [".ssh", ".DS_Store", ".localized", "._photo.jpg", ".com.google.Chrome.abc123"] {
            XCTAssertTrue(exists(name), "\(name) should stay where it is")
        }

        let attributes = try fm.attributesOfItem(atPath: root.appendingPathComponent(dir(.secrets)).path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    // MARK: - Locations and partial sorting

    @discardableResult
    private func sortWith(policy: SortPolicy = .downloads,
                          selection: Set<FileCategory>? = nil) throws -> (summary: SortSummary, runID: Int64) {
        let runID = try store.beginRun()
        let summary = try Sorter(root: root, minimumAge: 0, policy: policy, selection: selection)
            .sort { try self.store.record($0, runID: runID) }
        return (summary, runID)
    }

    func testPartialSortingMovesOnlyTheChosenTypes() throws {
        touch("photo.jpg")
        touch("report.pdf")
        touch("song.mp3")

        let result = try sortWith(selection: [.images])

        XCTAssertEqual(result.summary.moved, 1)
        XCTAssertTrue(exists("\(dir(.images))/photo.jpg"))
        XCTAssertTrue(exists("report.pdf"))
        XCTAssertTrue(exists("song.mp3"))
    }

    func testPartialSelectionAlsoAppliesToFoldersAndHiddenFiles() throws {
        try fm.createDirectory(at: root.appendingPathComponent("my-project"), withIntermediateDirectories: true)
        touch(".env")
        touch("a.pdf")

        let result = try sortWith(selection: [.documents])

        XCTAssertEqual(result.summary.moved, 1)
        XCTAssertTrue(exists("my-project"))
        XCTAssertTrue(exists(".env"))
        XCTAssertTrue(exists("\(dir(.documents))/a.pdf"))
    }

    func testCarefulPolicyLeavesHiddenFilesAlone() throws {
        touch(".gitignore")
        touch("a.pdf")

        let result = try sortWith(policy: .careful)

        XCTAssertEqual(result.summary.moved, 1)
        XCTAssertTrue(exists(".gitignore"))
    }

    func testHomeStylePolicyUsesExistingFoldersAndSkipsEverythingElse() throws {
        for name in ["Pictures", "Documents", "Library"] {
            try fm.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        touch("a.jpg")
        touch("b.pdf")
        touch("c.mp3")
        touch("d.py")
        touch(".zshrc")
        let policy = SortPolicy(
            includesHiddenFiles: false,
            includesFolders: false,
            allowedCategories: [.images, .documents],
            redirects: [.images: root.appendingPathComponent("Pictures"),
                        .documents: root.appendingPathComponent("Documents")]
        )

        let result = try sortWith(policy: policy)

        XCTAssertEqual(result.summary.moved, 2)
        XCTAssertTrue(exists("Pictures/a.jpg"))
        XCTAssertTrue(exists("Documents/b.pdf"))
        for untouched in ["c.mp3", "d.py", ".zshrc", "Library"] {
            XCTAssertTrue(exists(untouched), "\(untouched) should stay where it is")
        }
        XCTAssertFalse(exists(dir(.images)), "No new Images folder should be created")

        _ = try Reverter.revert(moves: try store.moves(forRun: result.runID), store: store)
        XCTAssertTrue(exists("a.jpg"))
        XCTAssertTrue(exists("Pictures"), "An existing folder must survive an undo")
    }

    func testHomePolicyIsRestricted() {
        let policy = SortPolicy.home()
        XCTAssertEqual(policy.allowedCategories, homeCategories)
        XCTAssertFalse(policy.includesFolders)
        XCTAssertFalse(policy.includesHiddenFiles)
        XCTAssertEqual(policy.redirects.count, homeCategories.count)
        for refused in [FileCategory.code, .config, .secrets, .databases, .projects, .other, .fonts] {
            XCTAssertFalse(policy.allowedCategories.contains(refused), "\(refused) must never be sorted in Home")
        }
    }

    func testFolderGuardRefusesRiskyFolders() {
        let home = URL(fileURLWithPath: "/Users/alex")
        func allowed(_ path: String) -> Bool {
            FolderGuard.isAllowedCustomFolder(URL(fileURLWithPath: path), home: home)
        }
        XCTAssertTrue(allowed("/Users/alex/Documents/Inbox"))
        XCTAssertTrue(allowed("/Volumes/Backup/Photos"))
        for refused in ["/", "/System/Library", "/Applications", "/Users", "/Users/alex", "/Users/alex/Library/Mail",
                        "/Users/alex/.ssh", "/Users/alex/Projects/.git", "/Volumes", "/Volumes/Backup",
                        "/Users/alex/Downloads/Thing.app/Contents"] {
            XCTAssertFalse(allowed(refused), refused)
        }
    }

    func testFolderGuardRecognisesProjects() throws {
        XCTAssertFalse(FolderGuard.looksLikeProject(root))
        touch("Package.swift")
        XCTAssertTrue(FolderGuard.looksLikeProject(root))
    }

    func testRunRemembersWhereItHappened() throws {
        touch("a.pdf")
        let runID = try store.beginRun(location: root.path)
        _ = try Sorter(root: root, minimumAge: 0).sort { try self.store.record($0, runID: runID) }

        XCTAssertEqual(try store.runs()[0].location, root.path)
    }

    func testSettingsAreRemembered() throws {
        XCTAssertNil(store.setting("location"))
        try store.setSetting("location", "desktop")
        XCTAssertEqual(store.setting("location"), "desktop")
        try store.setSetting("location", "home")
        XCTAssertEqual(store.setting("location"), "home")
        try store.setSetting("location", nil)
        XCTAssertNil(store.setting("location"))
    }

    @MainActor
    func testSelectiveModeLetsYouPickAndResetTypes() throws {
        let model = AppModel(demoStore: store, downloads: root, scan: ScanResult(), status: "", lastSortRunID: nil)
        XCTAssertTrue(model.isEverythingSelected)
        XCTAssertTrue(model.canSort)

        model.toggle(.images)
        XCTAssertTrue(model.selectedCategories.isEmpty, "Ticks are ignored while Everything is chosen")

        model.chooseSelective()
        XCTAssertFalse(model.isEverythingSelected)
        XCTAssertFalse(model.canSort, "Selective needs at least one type")

        model.toggle(.images)
        model.toggle(.documents)
        XCTAssertEqual(model.effectiveSelection, [.images, .documents])
        XCTAssertTrue(model.canSort)

        model.toggle(.images)
        XCTAssertEqual(model.effectiveSelection, [.documents])

        model.resetSelection()
        XCTAssertTrue(model.effectiveSelection.isEmpty)
        XCTAssertFalse(model.isEverythingSelected, "Reset clears the ticks but stays in Selective")

        model.chooseEverything()
        XCTAssertEqual(model.effectiveSelection, Set(FileCategory.allCases))
    }

    @MainActor
    func testHomeLimitsWhatCanBeSelected() throws {
        let model = AppModel(demoStore: store, downloads: root, scan: ScanResult(), status: "", lastSortRunID: nil)

        model.choose(.home)

        XCTAssertEqual(model.location, .home)
        XCTAssertEqual(model.allowedCategories, homeCategories)
        XCTAssertEqual(model.effectiveSelection, homeCategories)

        model.chooseSelective()
        model.toggle(.code)
        XCTAssertTrue(model.selectedCategories.isEmpty, "Code isn't allowed in Home, so it can't be ticked")
        model.toggle(.images)
        XCTAssertEqual(model.selectedCategories, [.images])
    }

    func testDatabasesGoToTheirOwnFolder() throws {
        touch("app.sqlite")
        touch("backup.sql")
        touch("deck.apkg")
        touch("script.py")

        let result = try sortWith()

        XCTAssertEqual(result.summary.moved, 4)
        for name in ["app.sqlite", "backup.sql", "deck.apkg"] {
            XCTAssertTrue(exists("\(dir(.databases))/\(name)"), name)
        }
        XCTAssertTrue(exists("\(dir(.code))/script.py"))
    }

    func testOldAnkiFolderIsNotMistakenForAProject() throws {
        try fm.createDirectory(at: root.appendingPathComponent("Anki"), withIntermediateDirectories: true)

        let result = try sortWith()

        XCTAssertEqual(result.summary.moved, 0)
        XCTAssertTrue(exists("Anki"))
        XCTAssertFalse(exists(dir(.projects)))
    }

    func testSelfInstallerFindsTheDiskImageForAVolume() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>images</key><array>
        <dict><key>image-path</key><string>/Users/me/Downloads/Other.dmg</string>
        <key>system-entities</key><array><dict><key>mount-point</key><string>/Volumes/Other</string></dict></array></dict>
        <dict><key>image-path</key><string>/Users/me/Downloads/Sottodesu-1.0.0.dmg</string>
        <key>system-entities</key><array><dict><key>dev-entry</key><string>/dev/disk4</string></dict>
        <dict><key>mount-point</key><string>/Volumes/Sottodesu</string></dict></array></dict>
        </array></dict></plist>
        """
        let data = Data(plist.utf8)
        let found = SelfInstaller.diskImage(containing: "/Volumes/Sottodesu/Sottodesu.app", hdiutilInfo: data)
        XCTAssertEqual(found, SelfInstaller.DiskImage(imagePath: "/Users/me/Downloads/Sottodesu-1.0.0.dmg", mountPoint: "/Volumes/Sottodesu"))
        XCTAssertNil(SelfInstaller.diskImage(containing: "/Applications/Sottodesu.app", hdiutilInfo: data))
        XCTAssertNil(SelfInstaller.diskImage(containing: "/Volumes/Sottodesu 2/Sottodesu.app", hdiutilInfo: data))
    }
}
