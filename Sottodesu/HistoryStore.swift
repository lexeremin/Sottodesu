import Foundation
import GRDB

/// One sort, like a commit: when it happened, how many items it moved, how big they were, and into which categories.
struct RunSummary: Identifiable, Equatable {
    let id: Int64
    let startedAt: Date
    let total: Int
    let reverted: Int
    let bytes: Int64
    let categories: [CategoryCount]
    /// The folder that was sorted (a path), if the history recorded it.
    let location: String?

    var isFullyReverted: Bool { total > 0 && reverted == total }
    var remaining: Int { total - reverted }

    /// "12 items · 4.2 GB"
    var subtitle: String {
        var text = String(localized: "\(total) items") + " · " + formatBytes(bytes)
        if reverted > 0 && !isFullyReverted { text += " · " + String(localized: "\(reverted) restored") }
        return text
    }

    /// "Images (5) · Documents (4) · Config & VPN (3)"
    var breakdown: String { CategoryCount.describe(categories) }
}

/// One file move inside a run.
struct LoggedMove: Identifiable, Equatable {
    let id: Int64
    let originalPath: String
    let newPath: String
    let category: String
    let size: Int64
    let createdFolder: Bool
    let revertedAt: Date?

    var fileName: String { URL(fileURLWithPath: newPath).lastPathComponent }

    init(row: Row) {
        id = row["id"]
        originalPath = row["originalPath"]
        newPath = row["newPath"]
        category = row["category"]
        size = row["size"]
        createdFolder = row["createdFolder"]
        let reverted: Double? = row["revertedAt"]
        revertedAt = reverted.map { Date(timeIntervalSince1970: $0) }
    }
}

/// The whole history lives in a single SQLite file.
final class HistoryStore: @unchecked Sendable {
    let dbQueue: DatabaseQueue

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: databaseURL.path)

        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE sort_run (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    startedAt REAL NOT NULL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE moved_file (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    runID INTEGER NOT NULL REFERENCES sort_run(id) ON DELETE CASCADE,
                    originalPath TEXT NOT NULL,
                    newPath TEXT NOT NULL,
                    category TEXT NOT NULL,
                    size INTEGER NOT NULL,
                    createdFolder INTEGER NOT NULL,
                    revertedAt REAL
                )
                """)
            try db.execute(sql: "CREATE INDEX moved_file_runID ON moved_file(runID)")
        }
        migrator.registerMigration("v2") { db in
            try db.execute(sql: "ALTER TABLE sort_run ADD COLUMN location TEXT")
            try db.execute(sql: "CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        }
        try migrator.migrate(dbQueue)
    }

    func beginRun(at date: Date = Date(), location: String? = nil) throws -> Int64 {
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO sort_run (startedAt, location) VALUES (?, ?)",
                           arguments: [date.timeIntervalSince1970, location])
            return db.lastInsertedRowID
        }
    }

    func record(_ file: MovedFile, runID: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO moved_file (runID, originalPath, newPath, category, size, createdFolder)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [runID, file.originalPath, file.newPath, file.category, file.size, file.createdFolder ? 1 : 0])
        }
    }

    /// Removes a run (and its moves) — used when a sort ended up moving nothing.
    func discardRun(_ runID: Int64) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM sort_run WHERE id = ?", arguments: [runID])
        }
    }

    func runs() throws -> [RunSummary] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT r.id AS id, r.startedAt AS startedAt,
                       COUNT(m.id) AS total, COUNT(m.revertedAt) AS reverted,
                       COALESCE(SUM(m.size), 0) AS bytes,
                       r.location AS location
                FROM sort_run r
                LEFT JOIN moved_file m ON m.runID = r.id
                GROUP BY r.id
                ORDER BY r.id DESC
                """)

            var byRun: [Int64: [CategoryCount]] = [:]
            let breakdown = try Row.fetchAll(db, sql: """
                SELECT runID, category, COUNT(*) AS n
                FROM moved_file
                GROUP BY runID, category
                """)
            for row in breakdown {
                let runID: Int64 = row["runID"]
                byRun[runID, default: []].append(CategoryCount(name: row["category"], count: row["n"]))
            }

            return rows.map { row in
                let id: Int64 = row["id"]
                let started: Double = row["startedAt"]
                return RunSummary(id: id, startedAt: Date(timeIntervalSince1970: started),
                                  total: row["total"], reverted: row["reverted"], bytes: row["bytes"],
                                  categories: CategoryCount.sorted(byRun[id] ?? []),
                                  location: row["location"])
            }
        }
    }

    func moves(forRun runID: Int64) throws -> [LoggedMove] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM moved_file WHERE runID = ? ORDER BY id",
                             arguments: [runID]).map(LoggedMove.init(row:))
        }
    }

    // MARK: Settings (kept in the same file as the history, so the app still writes only one file)

    func setting(_ key: String) -> String? {
        (try? dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [key])
        }) ?? nil
    }

    func setSetting(_ key: String, _ value: String?) throws {
        try dbQueue.write { db in
            if let value {
                try db.execute(sql: """
                    INSERT INTO setting (key, value) VALUES (?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value
                    """, arguments: [key, value])
            } else {
                try db.execute(sql: "DELETE FROM setting WHERE key = ?", arguments: [key])
            }
        }
    }

    func markReverted(moveID: Int64, at date: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE moved_file SET revertedAt = ? WHERE id = ?",
                           arguments: [date.timeIntervalSince1970, moveID])
        }
    }
}
