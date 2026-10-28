import Foundation

struct UndoSummary: Equatable {
    var restored = 0
    /// Files that were moved or deleted after sorting, so there is nothing to put back.
    var missing = 0
    /// Files that could not be restored because something already sits at the original path.
    var blocked = 0
}

enum Reverter {
    /// Puts files back where they came from, newest first. Never overwrites anything.
    static func revert(moves: [LoggedMove], store: HistoryStore) throws -> UndoSummary {
        let fm = FileManager.default
        var summary = UndoSummary()

        for move in moves.reversed() where move.revertedAt == nil {
            let current = URL(fileURLWithPath: move.newPath)
            let original = URL(fileURLWithPath: move.originalPath)

            if !fm.fileExists(atPath: current.path) {
                summary.missing += 1
                continue
            }
            if fm.fileExists(atPath: original.path) {
                summary.blocked += 1
                continue
            }

            try fm.moveItem(at: current, to: original)
            try store.markReverted(moveID: move.id)
            summary.restored += 1

            if move.createdFolder {
                removeIfEmpty(current.deletingLastPathComponent())
            }
        }
        return summary
    }

    private static func removeIfEmpty(_ folder: URL) {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        if contents.allSatisfy({ $0 == ".DS_Store" }) {
            try? fm.removeItem(at: folder)
        }
    }
}
