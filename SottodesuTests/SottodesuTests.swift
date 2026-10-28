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
        for ext in ["xml", "json", "rc", "jsonc", "yaml", "plist", "properties", "XML"] {
            XCTAssertEqual(FileCategory.of(extension: ext), .config, ext)
        }
        XCTAssertEqual(FileCategory.of(fileName: "settings.xml"), .config)
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

    // MARK: - Preview, search and schedules

    func testPlanListsWhatWouldMoveWithoutMovingAnything() throws {
        touch("a.jpg"); touch("b.pdf"); touch("c.jpg.crdownload")
        let plan = try Sorter(root: root).plan(now: Date().addingTimeInterval(60))
        XCTAssertEqual(plan.candidates.map(\.url.lastPathComponent), ["a.jpg", "b.pdf"])
        XCTAssertEqual(plan.skipped, 1)
        XCTAssertTrue(exists("a.jpg"))
        XCTAssertFalse(exists(dir(.images)))
    }

    func testSortingOnlyTheApprovedPaths() throws {
        touch("a.jpg"); touch("b.jpg"); touch("c.pdf")
        // Take the path the way the sorter reports it (macOS may spell /var as /private/var).
        let sorter = Sorter(root: root, minimumAge: 0)
        let first = try XCTUnwrap(try sorter.plan().candidates.first { $0.url.lastPathComponent == "a.jpg" })
        let approved: Set<String> = [first.url.path]
        let runID = try store.beginRun()
        let summary = try sorter.sort(only: approved) { try self.store.record($0, runID: runID) }
        XCTAssertEqual(summary.moved, 1)
        XCTAssertTrue(exists("\(dir(.images))/a.jpg"))
        XCTAssertTrue(exists("b.jpg"))
        XCTAssertTrue(exists("c.pdf"))
    }

    func testHistorySearchFindsMovesByNameAndRestoresOne() throws {
        touch("report.pdf"); touch("photo.jpg")
        try sortAll()
        let found = try store.search("report")
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found[0].move.fileName, "report.pdf")
        XCTAssertTrue(try store.search("   ").isEmpty)
        XCTAssertTrue(try store.search("%").isEmpty)

        let summary = try Reverter.revert(moves: [found[0].move], store: store)
        XCTAssertEqual(summary.restored, 1)
        XCTAssertTrue(exists("report.pdf"))
        XCTAssertTrue(exists("\(dir(.images))/photo.jpg"))
    }

    func testScheduleKnowsWhenItIsDue() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: 0))!
        }

        var daily = Schedule()
        daily.hour = 18
        daily.createdAt = date(10, 9)
        XCTAssertFalse(daily.isDue(now: date(10, 17), calendar: calendar))
        XCTAssertTrue(daily.isDue(now: date(10, 19), calendar: calendar))
        // Already ran today: not due again until tomorrow evening.
        daily.lastRunAt = date(10, 19)
        XCTAssertFalse(daily.isDue(now: date(11, 12), calendar: calendar))
        XCTAssertTrue(daily.isDue(now: date(11, 19), calendar: calendar))
        // A Mac that slept for days runs once, then waits for the next slot.
        daily.lastRunAt = date(10, 19)
        XCTAssertTrue(daily.isDue(now: date(15, 3), calendar: calendar))

        var weekly = Schedule()
        weekly.frequency = .weekly
        weekly.weekday = 2   // Monday; 2026-03-09 is a Monday
        weekly.hour = 8
        weekly.createdAt = date(10, 9)
        XCTAssertFalse(weekly.isDue(now: date(14, 12), calendar: calendar))
        XCTAssertTrue(weekly.isDue(now: date(16, 9), calendar: calendar))

        var monthly = Schedule()
        monthly.frequency = .monthly
        monthly.dayOfMonth = 20
        monthly.hour = 8
        monthly.createdAt = date(10, 9)
        XCTAssertFalse(monthly.isDue(now: date(19, 12), calendar: calendar))
        XCTAssertTrue(monthly.isDue(now: date(20, 9), calendar: calendar))

        var off = daily
        off.isEnabled = false
        off.lastRunAt = nil
        XCTAssertFalse(off.isDue(now: date(30, 12), calendar: calendar))
    }

    func testSchedulesAreSavedAndRead() throws {
        var schedule = Schedule()
        schedule.location = .desktop
        schedule.categories = [.images, .documents]
        schedule.frequency = .weekly
        schedule.weekday = 6
        schedule.hour = 7
        schedule.minute = 30
        let id = try store.save(schedule)
        XCTAssertNotEqual(id, 0)

        var saved = try XCTUnwrap(try store.schedules().first)
        XCTAssertEqual(saved.location, .desktop)
        XCTAssertEqual(saved.categories, [.images, .documents])
        XCTAssertEqual(saved.frequency, .weekly)
        XCTAssertEqual(saved.weekday, 6)
        XCTAssertEqual(saved.minute, 30)
        XCTAssertTrue(saved.isEnabled)

        saved.isEnabled = false
        try store.save(saved)
        XCTAssertEqual(try store.schedules().count, 1)
        XCTAssertFalse(try XCTUnwrap(try store.schedules().first).isEnabled)

        try store.deleteSchedule(id)
        XCTAssertTrue(try store.schedules().isEmpty)
    }

    func testScheduledRunSortsRecordsAndMarksItself() throws {
        touch("a.jpg"); touch("b.pdf")
        var schedule = Schedule()
        schedule.categories = [.images]
        schedule.id = try store.save(schedule)

        let outcome = ScheduleRunner.run(schedule, store: store, now: Date().addingTimeInterval(60),
                                         minimumAge: 0, rootOverride: root)
        XCTAssertEqual(outcome.moved, 1)
        XCTAssertNil(outcome.error)
        XCTAssertTrue(exists("\(dir(.images))/a.jpg"))
        XCTAssertTrue(exists("b.pdf"))

        let run = try XCTUnwrap(try store.runs().first)
        XCTAssertTrue(run.isScheduled)
        XCTAssertEqual(run.total, 1)
        XCTAssertEqual(try XCTUnwrap(try store.schedules().first).lastMoved, 1)

        // And it can be undone like any other sort.
        _ = try Reverter.revert(moves: try store.moves(forRun: run.id), store: store)
        XCTAssertTrue(exists("a.jpg"))
    }

    func testScheduledRunWithNothingToDoLeavesNoHistory() throws {
        var schedule = Schedule()
        schedule.id = try store.save(schedule)
        let outcome = ScheduleRunner.run(schedule, store: store, minimumAge: 0, rootOverride: root)
        XCTAssertEqual(outcome.moved, 0)
        XCTAssertTrue(try store.runs().isEmpty)
        XCTAssertEqual(try XCTUnwrap(try store.schedules().first).lastMoved, 0)
    }

    func testPausedSchedulesDoNotRun() throws {
        var schedule = Schedule()
        schedule.createdAt = Date(timeIntervalSince1970: 0)
        try store.save(schedule)
        try store.setSetting("schedulesPaused", "1")
        XCTAssertTrue(ScheduleRunner.runDue(store: store).isEmpty)
    }

    // MARK: - Updates

    func testVersionsCompareNumerically() {
        XCTAssertTrue(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        XCTAssertTrue(AppVersion("v1.4.0")! > AppVersion("1.3.0")!)
        XCTAssertEqual(AppVersion("1.3")!, AppVersion("1.3.0")!)
        XCTAssertFalse(AppVersion("1.3.0")! > AppVersion("1.3.0")!)
        XCTAssertNil(AppVersion("latest"))
        XCTAssertNil(AppVersion(""))
    }

    func testReleaseIsReadFromGitHubJSON() {
        let json = """
        {"tag_name":"v1.4.0","html_url":"https://github.com/lexeremin/Sottodesu/releases/tag/v1.4.0",
         "body":"Notes","draft":false,"prerelease":false,
         "assets":[{"name":"Sottodesu-1.4.0.dmg","browser_download_url":"https://github.com/lexeremin/Sottodesu/releases/download/v1.4.0/Sottodesu-1.4.0.dmg"},
                   {"name":"Sottodesu-1.4.0.dmg.sha256","browser_download_url":"https://github.com/lexeremin/Sottodesu/releases/download/v1.4.0/Sottodesu-1.4.0.dmg.sha256"}]}
        """
        let release = ReleaseInfo.parse(Data(json.utf8))
        XCTAssertEqual(release?.tag, "v1.4.0")
        XCTAssertEqual(release?.version, AppVersion("1.4.0"))
        XCTAssertEqual(release?.dmgURL?.lastPathComponent, "Sottodesu-1.4.0.dmg")
        XCTAssertEqual(release?.checksumURL?.lastPathComponent, "Sottodesu-1.4.0.dmg.sha256")
    }

    func testPrereleasesAndForeignDownloadsAreIgnored() {
        let pre = #"{"tag_name":"v2.0.0","html_url":"https://github.com/x/y","prerelease":true,"assets":[]}"#
        XCTAssertNil(ReleaseInfo.parse(Data(pre.utf8)))
        let foreign = """
        {"tag_name":"v2.0.0","html_url":"https://github.com/x/y","assets":
         [{"name":"a.dmg","browser_download_url":"https://evil.example.com/a.dmg"}]}
        """
        XCTAssertNil(ReleaseInfo.parse(Data(foreign.utf8))?.dmgURL)
        XCTAssertNil(ReleaseInfo.parse(Data("not json".utf8)))
    }

    func testChecksumFileIsParsed() {
        let hash = String(repeating: "ab", count: 32)
        XCTAssertEqual(ReleaseInfo.checksum(fromFile: "\(hash.uppercased())  Sottodesu-1.4.0.dmg\n"), hash)
        XCTAssertNil(ReleaseInfo.checksum(fromFile: "oops"))
    }
}
