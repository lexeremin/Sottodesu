import Foundation
import GRDB

struct CategoryStat: Identifiable, Equatable {
    /// The category's stable identifier (`FileCategory.rawValue`).
    let name: String
    let count: Int
    let bytes: Int64
    var id: String { name }
}

/// Everything the Report tab shows about the history.
struct HistoryReport: Equatable {
    var sorts = 0
    var items = 0
    var bytes: Int64 = 0
    var undone = 0
    var firstSort: Date?
    var lastSort: Date?
    var categories: [CategoryStat] = []
}

extension HistoryStore {
    func report() throws -> HistoryReport {
        try dbQueue.read { db in
            var report = HistoryReport()

            if let row = try Row.fetchOne(db, sql: """
                SELECT (SELECT COUNT(*) FROM sort_run) AS sorts,
                       (SELECT MIN(startedAt) FROM sort_run) AS firstSort,
                       (SELECT MAX(startedAt) FROM sort_run) AS lastSort,
                       COUNT(*) AS items,
                       COALESCE(SUM(size), 0) AS bytes,
                       COUNT(revertedAt) AS undone
                FROM moved_file
                """) {
                report.sorts = row["sorts"]
                report.items = row["items"]
                report.bytes = row["bytes"]
                report.undone = row["undone"]
                let first: Double? = row["firstSort"]
                let last: Double? = row["lastSort"]
                report.firstSort = first.map { Date(timeIntervalSince1970: $0) }
                report.lastSort = last.map { Date(timeIntervalSince1970: $0) }
            }

            let categoryRows = try Row.fetchAll(db, sql: """
                SELECT category, COUNT(*) AS n, COALESCE(SUM(size), 0) AS bytes
                FROM moved_file
                GROUP BY category
                """)
            report.categories = categoryRows
                .map { (row: Row) -> CategoryStat in
                    CategoryStat(name: row["category"], count: row["n"], bytes: row["bytes"])
                }
                .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }

            return report
        }
    }
}
